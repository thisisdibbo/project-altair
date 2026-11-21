import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/extras_models.dart';
import 'providers.dart';
import 'repositories/extras_repository.dart';

final extrasRepositoryProvider = Provider<ExtrasRepository>(
  (ref) => ExtrasRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityLoggerProvider),
  ),
);

/// A task's comments. Only listened to while its page is open.
final taskCommentsProvider = StreamProvider.autoDispose
    .family<List<TaskComment>, String>((ref, taskId) {
      if (ref.watch(uidProvider) == null) return Stream.empty();
      return ref.watch(extrasRepositoryProvider).watchComments(taskId);
    });

/// Team leads see every expense; everyone else only their own.
final expensesProvider = StreamProvider.autoDispose<List<Expense>>((ref) {
  final uid = ref.watch(uidProvider);
  final lead = ref.watch(
    currentUserProvider.select((u) => u.value?.role.isLead),
  );
  if (uid == null || lead == null) return Stream.empty();
  return ref
      .watch(extrasRepositoryProvider)
      .watchExpenses(ownerId: lead ? null : uid);
});

final pollsProvider = StreamProvider.autoDispose<List<Poll>>((ref) {
  if (ref.watch(uidProvider) == null) return Stream.empty();
  return ref.watch(extrasRepositoryProvider).watchPolls();
});
