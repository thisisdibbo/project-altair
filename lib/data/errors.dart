import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Turns any error into one sentence a team member can act on.
String friendlyError(Object error) {
  if (error is AppFailure) return error.message;
  if (error is TimeoutException) {
    return 'The server took too long to answer. Check your connection.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return 'No connection to the server. Check your internet and try again.';
      case 'unauthenticated':
        return error.message ?? 'Please sign in again.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Wrong User ID or password.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'That User ID is already taken.';
      case 'weak-password':
        return 'Choose a stronger password (at least 8 characters).';
      case 'requires-recent-login':
        return 'Log out, sign in again, then retry.';
      case 'operation-not-allowed':
        return 'Sign-in is not switched on in Firebase yet '
            '(BUILD_GUIDE.md, Part 3).';
      case 'resource-exhausted':
        return "Today's free database allowance is used up. "
            'It resets at midnight US Pacific time.';
      case 'internal':
      case 'unknown':
        return 'The server could not complete the request. Try again.';
    }
    return error.message ?? 'Request failed (${error.code}).';
  }
  return 'Something went wrong. Please try again.';
}

/// Firestore completes a write only after the server confirms it. Without a
/// connection the change is already saved on the phone and syncs later, so
/// we stop waiting after a moment. Returns false when it is still queued.
Future<bool> commit(Future<void> write) async {
  var confirmed = true;
  await write.timeout(
    const Duration(seconds: 4),
    onTimeout: () {
      confirmed = false;
    },
  );
  return confirmed;
}
