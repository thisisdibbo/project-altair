import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../app/config.dart';
import '../errors.dart';
import '../services/push.dart';

/// Sign-in uses a User ID and password issued by the administrator.
/// Firebase Authentication checks the password and keeps only a salted
/// hash of it, so nobody - not even an administrator - can read it back.
class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static final _idPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{2,31}$');

  /// 3-32 letters, digits, dot, dash or underscore, starting with a letter
  /// or digit. Upper and lower case are treated as the same ID.
  static bool validUserId(String userId) =>
      _idPattern.hasMatch(userId.trim().toLowerCase());

  /// The sign-in name Firebase keeps for a User ID.
  static String loginName(String userId) =>
      '${userId.trim().toLowerCase()}@${AppConfig.loginDomain}';

  Stream<User?> authState() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String userId, String password) async {
    if (!validUserId(userId)) {
      throw const AppFailure('Wrong User ID or password.');
    }
    await _auth.signInWithEmailAndPassword(
      email: loginName(userId),
      password: password,
    );
  }

  /// Makes the sign-in for someone asking to join. It stays locked:
  /// firestore.rules gives it nothing until a Super Admin approves the
  /// request, which creates the account itself.
  Future<void> register(String userId, String password) async {
    if (!validUserId(userId)) {
      throw const AppFailure(
        'Use 3-32 letters, digits, dot, dash or underscore for the User ID.',
      );
    }
    try {
      await _auth.createUserWithEmailAndPassword(
        email: loginName(userId),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw const AppFailure('That User ID is taken. Choose another one.');
      }
      if (e.code == 'weak-password') {
        throw const AppFailure('Choose a longer password.');
      }
      rethrow;
    }
  }

  /// Also stops closed-app notifications on this phone.
  Future<void> signOut() async {
    await Push.reset();
    await _auth.signOut();
  }

  /// Firebase asks for the current password again before it accepts a new
  /// one, so a phone left unlocked cannot be used to take over an account.
  Future<void> changePassword(String current, String next) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AppFailure('Please sign in again.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: current),
      );
    } on FirebaseAuthException catch (e) {
      const wrong = ['invalid-credential', 'wrong-password', 'user-mismatch'];
      if (wrong.contains(e.code)) {
        throw const AppFailure('Your current password is not correct.');
      }
      rethrow;
    }
    await user.updatePassword(next);
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .update({
            'mustChangePassword': false,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // The password is already changed. Clearing the reminder is retried
      // by Firestore when the phone is back online.
    }
  }
}
