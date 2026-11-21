import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors.dart';
import '../models/models.dart';
import 'admin_repository.dart' show LogActivity;

class TaskRepository {
  TaskRepository(this._db, this._log);

  final FirebaseFirestore _db;
  final LogActivity _log;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('tasks');
  CollectionReference<Map<String, dynamic>> get _history =>
      _db.collection('taskHistory');

  /// An id made up-front, so pressing Add twice can never create two tasks.
  String newId() => _tasks.doc().id;

  Stream<List<RoverTask>> watchActive() => _tasks
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(RoverTask.fromDoc).toList());

  Stream<List<RoverTask>> watchHistory({
    DateTime? from,
    DateTime? to,
    int limit = 200,
    bool newestFirst = true,
  }) {
    Query<Map<String, dynamic>> q = _history;
    if (from != null) {
      q = q.where('endedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('endedAt', isLessThan: Timestamp.fromDate(to));
    }
    return q
        .orderBy('endedAt', descending: newestFirst)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(RoverTask.fromDoc).toList());
  }

  Future<bool> create(String id, TaskDraft draft, AppUser me) async {
    final synced = await commit(
      _tasks.doc(id).set({
        ...draft.toMap(),
        'status': TaskStatus.pending.name,
        'startedAt': null,
        'startedById': '',
        'startedByName': '',
        'endedAt': null,
        'endedById': '',
        'endedByName': '',
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': me.id,
        'createdByName': me.fullName,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('task.created', 'Created task "${draft.title}"');
    return synced;
  }

  Future<bool> update(String id, TaskDraft draft) async {
    final synced = await commit(
      _tasks.doc(id).update({
        ...draft.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('task.edited', 'Edited task "${draft.title}"');
    return synced;
  }

  Future<bool> delete(String id, {String label = ''}) async {
    final synced = await commit(_tasks.doc(id).delete());
    _log('task.deleted', 'Deleted task "$label"');
    return synced;
  }

  /// The permanent record of a finished task, or null if there is none.
  Future<RoverTask?> finished(String id) async {
    final snap = await _history
        .doc(id)
        .get()
        .timeout(const Duration(seconds: 8));
    return snap.exists ? RoverTask.fromDoc(snap) : null;
  }

  /// START. Runs as a transaction so it needs the server: the start time is
  /// the server clock, and two people pressing START at once cannot both win.
  Future<void> start(String id, AppUser me) async {
    final title = await _db.runTransaction<String>((tx) async {
      final ref = _tasks.doc(id);
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) {
        throw const AppFailure('This task no longer exists.');
      }
      if (data['status'] != TaskStatus.pending.name) {
        throw const AppFailure('This task has already been started.');
      }
      tx.update(ref, {
        'status': TaskStatus.inProgress.name,
        'startedAt': FieldValue.serverTimestamp(),
        'startedById': me.id,
        'startedByName': me.fullName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return '${data['title'] ?? ''}';
    }, timeout: const Duration(seconds: 12));
    _log('task.started', 'Started task "$title"');
  }

  /// END TASK. Stamps the server end time, writes the permanent History
  /// record and removes the task from the live board - all or nothing.
  Future<void> end(String id, AppUser me) async {
    final title = await _db.runTransaction<String>((tx) async {
      final ref = _tasks.doc(id);
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) {
        throw const AppFailure('This task has already been completed.');
      }
      if (data['status'] != TaskStatus.inProgress.name) {
        throw const AppFailure('Start the task before ending it.');
      }
      tx.set(_history.doc(id), {
        ...data,
        'status': TaskStatus.completed.name,
        'endedAt': FieldValue.serverTimestamp(),
        'endedById': me.id,
        'endedByName': me.fullName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.delete(ref);
      return '${data['title'] ?? ''}';
    }, timeout: const Duration(seconds: 12));
    _log('task.completed', 'Completed task "$title"');
  }

  Future<bool> updateHistory(String id, TaskDraft draft) async {
    final synced = await commit(
      _history.doc(id).update({
        ...draft.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('task.edited', 'Corrected the history record "${draft.title}"');
    return synced;
  }

  Future<bool> deleteHistory(String id, {String label = ''}) async {
    final synced = await commit(_history.doc(id).delete());
    _log('task.deleted', 'Deleted the history record "$label"');
    return synced;
  }
}
