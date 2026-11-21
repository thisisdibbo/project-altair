import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/hub_models.dart';
import 'providers.dart';
import 'repositories/hub_repository.dart';

final hubRepositoryProvider = Provider<HubRepository>(
  (ref) => HubRepository(
    ref.watch(firestoreProvider),
    ref.watch(activityLoggerProvider),
  ),
);

/// Live data is only listened to while someone is signed in.
Stream<T> _signedIn<T>(Ref ref, Stream<T> Function() open) =>
    ref.watch(uidProvider) == null ? Stream<T>.empty() : open();

/// Only listened to while the inventory page is open.
final inventoryProvider = StreamProvider.autoDispose<List<InventoryItem>>(
  (ref) => _signedIn(ref, ref.watch(hubRepositoryProvider).watchInventory),
);

final eventsProvider = StreamProvider<List<TeamEvent>>(
  (ref) => _signedIn(ref, ref.watch(hubRepositoryProvider).watchEvents),
);

/// The nearest event that has not passed yet, or null.
final nextEventProvider = Provider<TeamEvent?>((ref) {
  final events = ref.watch(eventsProvider).value ?? const <TeamEvent>[];
  final now = DateTime.now();
  for (final e in events) {
    if (e.daysFrom(now) >= 0) return e;
  }
  return null;
});
