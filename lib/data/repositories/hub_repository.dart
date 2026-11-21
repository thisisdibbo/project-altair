import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors.dart';
import '../models/hub_models.dart';
import '../models/models.dart';
import 'admin_repository.dart' show LogActivity;

/// Team Hub data: the parts inventory and the team calendar.
class HubRepository {
  HubRepository(this._db, this._log);

  final FirebaseFirestore _db;
  final LogActivity _log;

  CollectionReference<Map<String, dynamic>> get _inventory =>
      _db.collection('inventory');
  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  // Inventory

  Stream<List<InventoryItem>> watchInventory() => _inventory
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(InventoryItem.fromDoc).toList());

  Future<bool> addItem(InventoryDraft draft) async {
    final synced = await commit(
      _inventory.doc().set({
        ...draft.toMap(),
        'borrowedById': '',
        'borrowedByName': '',
        'borrowedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('inventory.added', 'Added ${draft.name} to the inventory');
    return synced;
  }

  Future<bool> updateItem(String id, InventoryDraft draft) async {
    final synced = await commit(
      _inventory.doc(id).update({
        ...draft.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('inventory.edited', 'Edited ${draft.name} in the inventory');
    return synced;
  }

  Future<bool> deleteItem(String id, {String label = ''}) async {
    final synced = await commit(_inventory.doc(id).delete());
    _log('inventory.removed', 'Removed $label from the inventory');
    return synced;
  }

  /// Marks an item as taken. Runs as a transaction so it needs the server:
  /// the time is the server clock, and two members cannot both take it.
  Future<void> takeItem(String id, AppUser me) async {
    final name = await _db.runTransaction<String>((tx) async {
      final ref = _inventory.doc(id);
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) {
        throw const AppFailure('This item was removed.');
      }
      if ('${data['borrowedById'] ?? ''}'.isNotEmpty) {
        throw const AppFailure('Someone else already has this item.');
      }
      tx.update(ref, {
        'borrowedById': me.id,
        'borrowedByName': me.fullName,
        'borrowedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return '${data['name'] ?? ''}';
    }, timeout: const Duration(seconds: 12));
    _log('inventory.taken', 'Took $name from the inventory');
  }

  Future<bool> returnItem(InventoryItem item) async {
    final synced = await commit(
      _inventory.doc(item.id).update({
        'borrowedById': '',
        'borrowedByName': '',
        'borrowedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('inventory.returned', 'Returned ${item.name} to the inventory');
    return synced;
  }

  // Calendar

  /// Events from a month ago onwards, soonest first.
  Stream<List<TeamEvent>> watchEvents() => _events
      .where(
        'at',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 30)),
        ),
      )
      .orderBy('at')
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(TeamEvent.fromDoc).toList());

  Future<bool> addEvent(EventDraft draft, String byUid) async {
    final synced = await commit(
      _events.doc().set({
        ...draft.toMap(),
        'createdById': byUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('event.added', 'Added "${draft.title}" to the calendar');
    return synced;
  }

  Future<bool> updateEvent(String id, EventDraft draft) async {
    final synced = await commit(
      _events.doc(id).update({
        ...draft.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('event.edited', 'Edited "${draft.title}" in the calendar');
    return synced;
  }

  Future<bool> deleteEvent(String id, {String label = ''}) async {
    final synced = await commit(_events.doc(id).delete());
    _log('event.removed', 'Removed "$label" from the calendar');
    return synced;
  }
}
