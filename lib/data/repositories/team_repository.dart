import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors.dart';
import '../models/models.dart';
import 'admin_repository.dart' show LogActivity;

/// Accounts, sub-teams, the three member directories and the activity log.
class TeamRepository {
  TeamRepository(this._db, this._log);

  final FirebaseFirestore _db;
  final LogActivity _log;

  // Accounts

  Stream<AppUser?> watchUser(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Stream<List<AppUser>> watchUsers() => _db
      .collection('users')
      .orderBy('fullName')
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());

  Future<bool> setOwnPhoto(String uid, String url) => commit(
    _db.collection('users').doc(uid).update({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  // Sub-teams

  Stream<List<SubTeam>> watchSubTeams() => _db
      .collection('subTeams')
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(SubTeam.fromDoc).toList());

  Future<bool> addSubTeam(String name, int order, String byUid) async {
    final synced = await commit(
      _db.collection('subTeams').doc().set({
        'name': name,
        'order': order,
        'createdBy': byUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('subteam.added', 'Added sub-team $name');
    return synced;
  }

  Future<bool> renameSubTeam(String id, String name) async {
    final synced = await commit(
      _db.collection('subTeams').doc(id).update({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('subteam.renamed', 'Renamed a sub-team to $name');
    return synced;
  }

  Future<bool> deleteSubTeam(String id, {String label = ''}) async {
    final synced = await commit(_db.collection('subTeams').doc(id).delete());
    _log('subteam.deleted', 'Deleted sub-team $label');
    return synced;
  }

  Future<bool> swapSubTeams(SubTeam a, SubTeam b) {
    final batch = _db.batch();
    final col = _db.collection('subTeams');
    batch.update(col.doc(a.id), {
      'order': b.order,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(col.doc(b.id), {
      'order': a.order,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return commit(batch.commit());
  }

  // Member directories

  String newMemberId(MemberGroup group) =>
      _db.collection(group.collection).doc().id;

  Stream<List<Member>> watchMembers(MemberGroup group) => _db
      .collection(group.collection)
      .orderBy('fullName')
      .snapshots()
      .map((s) => s.docs.map(Member.fromDoc).toList());

  Future<bool> saveMember(
    MemberGroup group,
    String id,
    Map<String, dynamic> fields, {
    required bool isNew,
    required String byUid,
  }) async {
    final ref = _db.collection(group.collection).doc(id);
    final data = {...fields, 'updatedAt': FieldValue.serverTimestamp()};
    final synced = await commit(
      isNew
          ? ref.set({
              ...data,
              'createdBy': byUid,
              'createdAt': FieldValue.serverTimestamp(),
            })
          : ref.update(data),
    );
    final name = '${fields['fullName'] ?? ''}';
    _log(
      isNew ? 'member.added' : 'member.edited',
      isNew
          ? 'Added $name to ${group.title}'
          : 'Edited $name in ${group.title}',
    );
    return synced;
  }

  Future<bool> deleteMember(
    MemberGroup group,
    String id, {
    String label = '',
  }) async {
    final synced = await commit(
      _db.collection(group.collection).doc(id).delete(),
    );
    _log('member.removed', 'Removed $label from ${group.title}');
    return synced;
  }

  /// Moves a card up to a higher directory. When the card is the member's
  /// own (its ID is their account ID), their account gets the matching role.
  Future<bool> promoteMember(MemberGroup from, MemberGroup to, Member m) async {
    final card = await _db.collection(from.collection).doc(m.id).get();
    if (!card.exists) throw const AppFailure('This profile was removed.');
    final account = await _db.collection('users').doc(m.id).get();
    final batch = _db.batch();
    batch.set(_db.collection(to.collection).doc(m.id), {
      ...?card.data(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(card.reference);
    if (account.exists && !Role.parse(account.data()?['role']).isLead) {
      batch.update(account.reference, {
        'role': to.role!.key,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final synced = await commit(batch.commit());
    _log('member.promoted', 'Promoted ${m.fullName} to ${to.singular}');
    return synced;
  }

  // Activity

  Stream<List<ActivityLog>> watchActivity({int limit = 200}) => _db
      .collection('activityLogs')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(ActivityLog.fromDoc).toList());
}
