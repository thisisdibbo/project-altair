import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart' show Doc;

String _str(Object? v) => v is String ? v : '';
DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

/// One line of a task's checklist. The list is kept inside the task itself,
/// so it travels with the task into History.
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.text,
    required this.done,
  });

  final String id;
  final String text;
  final bool done;

  ChecklistItem copyWith({bool? done}) =>
      ChecklistItem(id: id, text: text, done: done ?? this.done);

  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'done': done};

  /// Reads the stored list, skipping anything that is not a proper item.
  static List<ChecklistItem> listFrom(Object? value) {
    if (value is! List) return const [];
    return [
      for (final v in value)
        if (v is Map && _str(v['id']).isNotEmpty)
          ChecklistItem(
            id: _str(v['id']),
            text: _str(v['text']),
            done: v['done'] == true,
          ),
    ];
  }
}

class TaskComment {
  const TaskComment({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    this.createdAt,
  });

  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final DateTime? createdAt;

  factory TaskComment.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return TaskComment(
      id: doc.id,
      text: _str(d['text']),
      authorId: _str(d['authorId']),
      authorName: _str(d['authorName']),
      createdAt: _date(d['createdAt']),
    );
  }
}

/// A purchase a member paid for and wants paid back.
class Expense {
  const Expense({
    required this.id,
    required this.reason,
    required this.amount,
    required this.bkash,
    required this.receiptUrl,
    required this.createdById,
    required this.createdByName,
    this.createdAt,
  });

  final String id;
  final String reason;
  final double amount;

  /// The bKash number the money should be sent back to.
  final String bkash;

  /// Reference to the receipt photo ("db:<id>").
  final String receiptUrl;
  final String createdById;
  final String createdByName;
  final DateTime? createdAt;

  factory Expense.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final amount = d['amount'];
    return Expense(
      id: doc.id,
      reason: _str(d['reason']),
      amount: amount is num ? amount.toDouble() : 0,
      bkash: _str(d['bkash']),
      receiptUrl: _str(d['receiptUrl']),
      createdById: _str(d['createdById']),
      createdByName: _str(d['createdByName']),
      createdAt: _date(d['createdAt']),
    );
  }
}

class Poll {
  const Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    required this.closed,
    required this.createdById,
    required this.createdByName,
    this.createdAt,
  });

  final String id;
  final String question;
  final List<String> options;

  /// Account id -> position of the option that member chose.
  final Map<String, int> votes;
  final bool closed;
  final String createdById;
  final String createdByName;
  final DateTime? createdAt;

  int get total => votes.length;

  int countFor(int option) => votes.values.where((v) => v == option).length;

  /// The option this member chose, or null if they have not voted.
  int? choiceOf(String? uid) => uid == null ? null : votes[uid];

  factory Poll.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final options = d['options'];
    final votes = d['votes'];
    return Poll(
      id: doc.id,
      question: _str(d['question']),
      options: options is List ? [for (final o in options) _str(o)] : const [],
      votes: votes is Map
          ? {
              for (final e in votes.entries)
                if (e.key is String && e.value is int)
                  e.key as String: e.value as int,
            }
          : const {},
      closed: d['closed'] == true,
      createdById: _str(d['createdById']),
      createdByName: _str(d['createdByName']),
      createdAt: _date(d['createdAt']),
    );
  }
}
