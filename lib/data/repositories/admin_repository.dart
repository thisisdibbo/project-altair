import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../app/config.dart';
import '../errors.dart';
import '../models/models.dart';
import 'auth_repository.dart';

typedef LogActivity = void Function(String type, String message);

/// Account management for Super Admins. The app holds no admin secret:
/// firestore.rules checks the caller's role on every one of these writes.
class AdminRepository {
  AdminRepository(this._db, this._log);

  final FirebaseFirestore _db;
  final LogActivity _log;

  static const _wait = Duration(seconds: 12);

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  Future<void> createUser({
    required String userId,
    required String password,
    required String fullName,
    required Role role,
    required String position,
    required String subTeamId,
    required String subTeamName,
  }) async {
    if (!AuthRepository.validUserId(userId)) {
      throw const AppFailure(
        'Use 3-32 letters, digits, dot, dash or underscore for the User ID.',
      );
    }
    final uid = await _register(AuthRepository.loginName(userId), password);
    await _user(uid)
        .set({
          'userId': userId.trim(),
          'fullName': fullName,
          'role': role.key,
          'position': position,
          'subTeamId': subTeamId,
          'subTeamName': subTeamName,
          'photoUrl': '',
          'disabled': false,
          'mustChangePassword': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_wait);
    _log('user.created', 'Created the account of $fullName (${role.label})');
  }

  /// Creating a sign-in on the main connection would sign the administrator
  /// out, so it is done on a second, short-lived connection to Firebase.
  Future<String> _register(String loginName, String password) async {
    final helper = await Firebase.initializeApp(
      name: 'account-setup-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final auth = FirebaseAuth.instanceFor(app: helper);
      if (AppConfig.useEmulators) {
        await auth.useAuthEmulator(AppConfig.emulatorHost, 9099);
      }
      final uid = await _createOrResume(auth, loginName, password);
      await auth.signOut();
      return uid;
    } finally {
      await helper.delete();
    }
  }

  Future<String> _createOrResume(
    FirebaseAuth auth,
    String loginName,
    String password,
  ) async {
    try {
      final created = await auth.createUserWithEmailAndPassword(
        email: loginName,
        password: password,
      );
      final uid = created.user?.uid;
      if (uid != null) return uid;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
    }
    // The ID exists. If an earlier attempt stopped half-way (sign-in made,
    // profile not saved) and the same password is used, finish that attempt.
    try {
      final existing = await auth.signInWithEmailAndPassword(
        email: loginName,
        password: password,
      );
      final uid = existing.user?.uid;
      if (uid != null && !(await _user(uid).get().timeout(_wait)).exists) {
        return uid;
      }
    } on FirebaseAuthException catch (_) {}
    throw const AppFailure('That User ID is already taken.');
  }

  Future<void> updateUser({
    required String uid,
    required String fullName,
    required Role role,
    required String position,
    required String subTeamId,
    required String subTeamName,
  }) async {
    await _user(uid)
        .update({
          'fullName': fullName,
          'role': role.key,
          'position': position,
          'subTeamId': subTeamId,
          'subTeamName': subTeamName,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_wait);
    _log('user.updated', 'Updated the account of $fullName (${role.label})');
  }

  /// Removes an account for good: the account, the member's profile card
  /// on every page, and a note asking the team's Apps Script to delete the
  /// sign-in itself. On the free plan a phone cannot delete somebody else's
  /// sign-in; the script can, with the team's service account.
  Future<void> deleteUser(AppUser user) async {
    final batch = _db.batch();
    batch.delete(_user(user.id));
    for (final g in MemberGroup.values) {
      batch.delete(_db.collection(g.collection).doc(user.id));
    }
    batch.set(_db.collection('accountDeletions').doc(user.id), {
      'userId': user.userId,
      'fullName': user.fullName,
      'requestedById': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit().timeout(_wait);
    _log('user.deleted', 'Deleted the account of ${user.fullName}');
  }

  /// A disabled account is refused by firestore.rules at once and the
  /// member's own phone signs out as soon as it sees the change.
  Future<void> setDisabled(
    String uid,
    bool disabled, {
    String label = '',
  }) async {
    await _user(uid)
        .update({
          'disabled': disabled,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_wait);
    _log(
      disabled ? 'user.disabled' : 'user.enabled',
      '${disabled ? 'Disabled' : 'Enabled'} the account of $label',
    );
  }
}
