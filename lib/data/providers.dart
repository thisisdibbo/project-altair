import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/models.dart';
import 'permissions.dart';
import 'repositories/admin_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/note_repository.dart';
import 'repositories/photo_repository.dart';
import 'repositories/task_repository.dart';
import 'repositories/team_repository.dart';
import 'services/push.dart';
import 'services/server_clock.dart';

// Backend handle

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Adds a line to the administrators' activity log, signed with the
/// current member. firestore.rules refuses a line signed as anyone else.
final Provider<LogActivity> activityLoggerProvider = Provider<LogActivity>((ref) {
  final db = ref.watch(firestoreProvider);
  return (type, message) {
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    db.collection('activityLogs').add({
      'type': type,
      'message': message,
      'actorId': me.id,
      'actorName': me.fullName,
      'createdAt': FieldValue.serverTimestamp(),
    }).ignore();
    if (_notifyAfter.contains(type)) Push.nudge();
  };
});

/// Changes that can lead to a notification or a new expense-sheet row.
const _notifyAfter = {
  'task.created',
  'task.started',
  'task.completed',
  'note.created',
  'poll.added',
  'event.added',
  'expense.added',
  'inventory.added',
  'inventory.edited',
  'inventory.removed',
  'inventory.taken',
  'inventory.returned',
  'user.deleted',
};

// Repositories and services

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(FirebaseAuth.instance, ref.watch(firestoreProvider)),
);

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityLoggerProvider),
  ),
);

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityLoggerProvider),
  ),
);

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityLoggerProvider),
  ),
);

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityLoggerProvider),
  ),
);

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => PhotoRepository(ref.watch(firestoreProvider)),
);

final serverClockProvider = Provider<ServerClock>(
  (ref) => ServerClock(ref.watch(firestoreProvider)),
);

// Session

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authState(),
);

final uidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream<AppUser?>.value(null);
    return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);
});

final permissionsProvider = Provider<Permissions?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user == null ? null : Permissions(user);
});

/// Live data is only listened to while someone is signed in.
Stream<T> _signedIn<T>(Ref ref, Stream<T> Function() open) =>
    ref.watch(uidProvider) == null ? Stream<T>.empty() : open();

// Live collections

final activeTasksProvider = StreamProvider<List<RoverTask>>(
  (ref) => _signedIn(ref, ref.watch(taskRepositoryProvider).watchActive),
);

final recentCompletedProvider = StreamProvider<List<RoverTask>>(
  (ref) => _signedIn(
    ref,
    () => ref.watch(taskRepositoryProvider).watchHistory(limit: 20),
  ),
);

@immutable
class HistoryQuery {
  const HistoryQuery({
    this.from,
    this.to,
    this.limit = pageSize,
    this.newestFirst = true,
  });

  static const pageSize = 50;

  final DateTime? from;
  final DateTime? to;
  final int limit;
  final bool newestFirst;

  HistoryQuery copyWith({int? limit, bool? newestFirst}) => HistoryQuery(
    from: from,
    to: to,
    limit: limit ?? this.limit,
    newestFirst: newestFirst ?? this.newestFirst,
  );

  HistoryQuery withRange(DateTime? from, DateTime? to) =>
      HistoryQuery(from: from, to: to, newestFirst: newestFirst);

  @override
  bool operator ==(Object other) =>
      other is HistoryQuery &&
      other.from == from &&
      other.to == to &&
      other.limit == limit &&
      other.newestFirst == newestFirst;

  @override
  int get hashCode => Object.hash(from, to, limit, newestFirst);
}

class HistoryQueryNotifier extends Notifier<HistoryQuery> {
  @override
  HistoryQuery build() => const HistoryQuery();

  void apply(HistoryQuery query) => state = query;
}

final historyQueryProvider =
    NotifierProvider<HistoryQueryNotifier, HistoryQuery>(
      HistoryQueryNotifier.new,
    );

final historyProvider = StreamProvider<List<RoverTask>>((ref) {
  final q = ref.watch(historyQueryProvider);
  return _signedIn(
    ref,
    () => ref
        .watch(taskRepositoryProvider)
        .watchHistory(
          from: q.from,
          to: q.to,
          limit: q.limit,
          newestFirst: q.newestFirst,
        ),
  );
});

final notesProvider = StreamProvider<List<Note>>(
  (ref) => _signedIn(ref, () => ref.watch(noteRepositoryProvider).watch()),
);

/// The three newest notes: a very small listener that is enough to announce
/// an important note without loading the whole noticeboard.
final latestNotesProvider = StreamProvider<List<Note>>(
  (ref) => _signedIn(
    ref,
    () => ref.watch(noteRepositoryProvider).watch(limit: 3),
  ),
);

final membersProvider = StreamProvider.family<List<Member>, MemberGroup>(
  (ref, group) => _signedIn(
    ref,
    () => ref.watch(teamRepositoryProvider).watchMembers(group),
  ),
);

final subTeamsProvider = StreamProvider<List<SubTeam>>(
  (ref) => _signedIn(ref, ref.watch(teamRepositoryProvider).watchSubTeams),
);

final usersProvider = StreamProvider<List<AppUser>>(
  (ref) => _signedIn(ref, ref.watch(teamRepositoryProvider).watchUsers),
);

final activityProvider = StreamProvider<List<ActivityLog>>(
  (ref) => _signedIn(
    ref,
    () => ref.watch(teamRepositoryProvider).watchActivity(),
  ),
);
