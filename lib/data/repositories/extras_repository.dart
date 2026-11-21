import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors.dart';
import '../models/extras_models.dart';
import '../models/models.dart';
import 'admin_repository.dart' show LogActivity;

/// Task checklists and comments, the expense log and polls.
class ExtrasRepository {
  ExtrasRepository(this._db, this._log);

  final FirebaseFirestore _db;
  final LogActivity _log;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('tasks');
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _db.collection('expenses');
  CollectionReference<Map<String, dynamic>> get _polls =>
      _db.collection('polls');
  CollectionReference<Map<String, dynamic>> _comments(String taskId) =>
      _tasks.doc(taskId).collection('comments');

  // Task checklist

  /// Reads the task's checklist on the server, applies [change] and saves
  /// it back in one step, so two members editing at once cannot lose a line.
  Future<void> _editChecklist(
    String taskId,
    List<ChecklistItem> Function(List<ChecklistItem> items) change,
  ) => _db.runTransaction<void>((tx) async {
    final ref = _tasks.doc(taskId);
    final snap = await tx.get(ref);
    final data = snap.data();
    if (data == null) {
      throw const AppFailure('This task is no longer on the live board.');
    }
    final items = change(ChecklistItem.listFrom(data['checklist']));
    if (items.length > 40) {
      throw const AppFailure('A checklist can hold up to 40 items.');
    }
    tx.update(ref, {
      'checklist': [for (final i in items) i.toMap()],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }, timeout: const Duration(seconds: 12));

  Future<void> addChecklistItem(String taskId, String text) => _editChecklist(
    taskId,
    (items) => [
      ...items,
      ChecklistItem(id: _tasks.doc().id, text: text, done: false),
    ],
  );

  Future<void> toggleChecklistItem(String taskId, String itemId) =>
      _editChecklist(
        taskId,
        (items) => [
          for (final i in items)
            if (i.id == itemId) i.copyWith(done: !i.done) else i,
        ],
      );

  Future<void> removeChecklistItem(String taskId, String itemId) =>
      _editChecklist(
        taskId,
        (items) => [
          for (final i in items)
            if (i.id != itemId) i,
        ],
      );

  // Task comments

  Stream<List<TaskComment>> watchComments(String taskId) => _comments(taskId)
      .orderBy('createdAt')
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(TaskComment.fromDoc).toList());

  Future<bool> addComment(String taskId, String text, AppUser me) => commit(
    _comments(taskId).doc().set({
      'text': text,
      'authorId': me.id,
      'authorName': me.fullName,
      'createdAt': FieldValue.serverTimestamp(),
    }),
  );

  Future<bool> deleteComment(String taskId, String commentId) =>
      commit(_comments(taskId).doc(commentId).delete());

  // Expense log

  /// Every entry (for team leads), or only [ownerId]'s own. Newest first.
  Stream<List<Expense>> watchExpenses({String? ownerId}) {
    final Query<Map<String, dynamic>> q = ownerId == null
        ? _expenses.orderBy('createdAt', descending: true).limit(200)
        : _expenses.where('createdById', isEqualTo: ownerId).limit(200);
    return q.snapshots().map((s) {
      final list = s.docs.map(Expense.fromDoc).toList();
      final far = DateTime.now().add(const Duration(days: 1));
      list.sort((a, b) => (b.createdAt ?? far).compareTo(a.createdAt ?? far));
      return list;
    });
  }

  Future<bool> addExpense({
    required String reason,
    required double amount,
    required String bkash,
    required String receiptUrl,
    required AppUser me,
  }) async {
    final synced = await commit(
      _expenses.doc().set({
        'reason': reason,
        'amount': amount,
        'bkash': bkash,
        'receiptUrl': receiptUrl,
        'createdById': me.id,
        'createdByName': me.fullName,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('expense.added', 'Logged an expense: $reason');
    return synced;
  }

  Future<bool> deleteExpense(String id, {String label = ''}) async {
    final synced = await commit(_expenses.doc(id).delete());
    _log('expense.removed', 'Removed the expense: $label');
    return synced;
  }

  // Polls

  Stream<List<Poll>> watchPolls() => _polls
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(Poll.fromDoc).toList());

  Future<bool> addPoll(
    String question,
    List<String> options,
    AppUser me,
  ) async {
    final synced = await commit(
      _polls.doc().set({
        'question': question,
        'options': options,
        'votes': <String, int>{},
        'closed': false,
        'createdById': me.id,
        'createdByName': me.fullName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('poll.added', 'Started the poll "$question"');
    return synced;
  }

  /// Records (or changes) this member's vote. Only their own entry is sent.
  Future<bool> vote(String pollId, String uid, int option) => commit(
    _polls.doc(pollId).update({
      'votes.$uid': option,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  Future<bool> setPollClosed(String pollId, bool closed) => commit(
    _polls.doc(pollId).update({
      'closed': closed,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  Future<bool> deletePoll(String id, {String label = ''}) async {
    final synced = await commit(_polls.doc(id).delete());
    _log('poll.removed', 'Deleted the poll "$label"');
    return synced;
  }
}
