import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/models.dart';
import 'providers.dart';
import 'repositories/admin_repository.dart' show LogActivity;

/// Someone asking to join. They made their own sign-in, which stays locked
/// (firestore.rules gives it nothing) until a Super Admin approves them.
class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.studentId,
    required this.group,
    required this.position,
    required this.subTeamId,
    required this.subTeamName,
    required this.phone,
    required this.whatsapp,
    required this.messengerLink,
    required this.photo,
    required this.rejected,
    required this.createdAt,
  });

  /// The applicant's Firebase account id; their card and account get it too.
  final String id;
  final String userId;
  final String fullName;
  final String studentId;

  /// The page they asked to be listed on.
  final MemberGroup group;
  final String position;
  final String subTeamId;
  final String subTeamName;
  final String phone;
  final String whatsapp;
  final String messengerLink;

  /// The profile picture as a data URL, until the request is decided.
  final String photo;
  final bool rejected;
  final DateTime? createdAt;

  Uint8List? get photoBytes {
    final comma = photo.indexOf(',');
    if (!photo.startsWith('data:image/') || comma < 0) return null;
    try {
      return base64Decode(photo.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  factory JoinRequest.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    String str(String key) => d[key] is String ? d[key] as String : '';
    final at = d['createdAt'];
    return JoinRequest(
      id: doc.id,
      userId: str('userId'),
      fullName: str('fullName'),
      studentId: str('studentId'),
      group: joinGroups.firstWhere(
        (g) => g.collection == d['group'],
        orElse: () => MemberGroup.juniorMembers,
      ),
      position: str('position'),
      subTeamId: str('subTeamId'),
      subTeamName: str('subTeamName'),
      phone: str('phone'),
      whatsapp: str('whatsapp'),
      messengerLink: str('messengerLink'),
      photo: str('photo'),
      rejected: d['status'] == 'rejected',
      createdAt: at is Timestamp ? at.toDate() : null,
    );
  }
}

/// The pages someone can ask to join.
const joinGroups = [
  MemberGroup.juniorMembers,
  MemberGroup.seniorMembers,
  MemberGroup.teamLeads,
  MemberGroup.advisors,
  MemberGroup.moderators,
];

String joinGroupName(MemberGroup g) => switch (g) {
  MemberGroup.teamLeads => 'Lead',
  MemberGroup.seniorMembers => 'Senior member',
  MemberGroup.juniorMembers => 'Junior member',
  MemberGroup.advisors => 'Advisor',
  MemberGroup.moderators => 'Moderator',
};

/// The signed-in person's own request (only someone without an account
/// has one).
final myJoinRequestProvider = StreamProvider<JoinRequest?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('joinRequests')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? JoinRequest.fromDoc(d) : null);
});

/// Requests waiting for a Super Admin, oldest first.
final pendingJoinRequestsProvider = StreamProvider<List<JoinRequest>>((ref) {
  final admin = ref.watch(
    currentUserProvider.select((u) => u.value?.role.isAdmin ?? false),
  );
  if (!admin) return Stream.value(const <JoinRequest>[]);
  return ref
      .watch(firestoreProvider)
      .collection('joinRequests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) {
        final list = s.docs.map(JoinRequest.fromDoc).toList();
        final never = DateTime.fromMillisecondsSinceEpoch(0);
        list.sort(
          (a, b) => (a.createdAt ?? never).compareTo(b.createdAt ?? never),
        );
        return list;
      });
});

final joinRequestsProvider = Provider<JoinRequests>(
  (ref) => JoinRequests(
    FirebaseAuth.instance,
    ref.watch(firestoreProvider),
    ref.watch(activityLoggerProvider),
  ),
);

class JoinRequests {
  JoinRequests(this._auth, this._db, this._log);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final LogActivity _log;

  static const _wait = Duration(seconds: 25);

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('joinRequests');

  static String _dataUrl(Uint8List bytes) {
    final png =
        bytes.length > 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E;
    return 'data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}';
  }

  /// Sends the applicant's profile for approval. The login ID is the one
  /// they signed up with (firestore.rules checks it).
  Future<void> send({
    required String fullName,
    required String studentId,
    required MemberGroup group,
    required String position,
    required String subTeamId,
    required String subTeamName,
    required String phone,
    required String whatsapp,
    required String messengerLink,
    required Uint8List photo,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return;
    await _requests
        .doc(user.uid)
        .set({
          'userId': email.split('@').first,
          'fullName': fullName,
          'studentId': studentId,
          'group': group.collection,
          'position': position,
          'subTeamId': subTeamId,
          'subTeamName': subTeamName,
          'phone': phone,
          'whatsapp': whatsapp,
          'messengerLink': messengerLink,
          'photo': _dataUrl(photo),
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(_wait);
  }

  /// The applicant cancels: their request and their sign-in are deleted,
  /// so they can start again from the sign-in screen.
  Future<void> withdraw() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _requests.doc(user.uid).delete().timeout(_wait);
    } on FirebaseException catch (_) {}
    try {
      await user.delete();
    } on FirebaseAuthException catch (_) {
      // Firebase wants a fresh sign-in before deleting an older login. The
      // request is gone, so signing out is enough: the login stays locked
      // and can do nothing.
      await _auth.signOut();
    }
  }

  /// Opens the account with the matching role and puts the profile card,
  /// with its picture, on the chosen page, all in one step.
  Future<void> approve(
    JoinRequest r, {
    required MemberGroup group,
    required String subTeamId,
    required String subTeamName,
    required AppUser admin,
  }) async {
    final role = group.role ?? Role.junior;
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    var photoUrl = '';
    if (r.photoBytes != null) {
      final photo = _db.collection('photos').doc();
      photoUrl = 'db:${photo.id}';
      batch.set(photo, {
        'image': r.photo,
        'ownerId': admin.id,
        'createdAt': now,
      });
    }
    batch.set(_db.collection('users').doc(r.id), {
      'userId': r.userId,
      'fullName': r.fullName,
      'role': role.key,
      'position': r.position,
      'subTeamId': subTeamId,
      'subTeamName': subTeamName,
      'photoUrl': photoUrl,
      'disabled': false,
      'mustChangePassword': false,
      'createdAt': now,
      'updatedAt': now,
    });
    batch.set(_db.collection(group.collection).doc(r.id), {
      'fullName': r.fullName,
      'position': r.position,
      'subTeamId': subTeamId,
      'subTeamName': subTeamName,
      'phone': r.phone,
      'whatsapp': r.whatsapp,
      'messengerLink': r.messengerLink,
      'photoUrl': photoUrl,
      'order': 0,
      'createdBy': admin.id,
      'createdAt': now,
      'updatedAt': now,
    });
    batch.delete(_requests.doc(r.id));
    await batch.commit().timeout(_wait);
    _log('user.approved', 'Approved ${r.fullName} as ${role.label}');
  }

  Future<void> reject(JoinRequest r, AppUser admin) async {
    await _requests
        .doc(r.id)
        .update({
          'status': 'rejected',
          'photo': '',
          'decidedById': admin.id,
          'decidedByName': admin.fullName,
          'decidedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_wait);
    _log('user.rejected', 'Did not approve the request of ${r.fullName}');
  }
}
