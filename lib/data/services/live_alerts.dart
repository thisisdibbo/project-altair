import '../models/models.dart';

class AlertTopic {
  const AlertTopic(this.key, this.title, this.subtitle, {this.leadsOnly = false});

  final String key;
  final String title;
  final String subtitle;

  /// Offered to team leads only.
  final bool leadsOnly;
}

const alertTopics = <AlertTopic>[
  AlertTopic('taskCreated', 'New tasks', 'A task is added to the board'),
  AlertTopic('taskStarted', 'Task started', 'A member starts a task'),
  AlertTopic('taskCompleted', 'Task completed', 'A task is finished'),
  AlertTopic(
    'importantNotes',
    'Important notes',
    'An important or pinned note is published',
  ),
  AlertTopic('newPolls', 'New polls', 'Someone asks the team to vote'),
  AlertTopic(
    'newEvents',
    'Calendar',
    'A meeting, test day or deadline is added',
  ),
  AlertTopic(
    'newExpenses',
    'New expenses',
    'A member logs a purchase to be paid back',
    leadsOnly: true,
  ),
];

class LiveAlert {
  const LiveAlert(this.topic, this.message);

  final String topic;
  final String message;
}

/// Works out what teammates just did by comparing two snapshots of the live
/// data. The app shows the result as a banner while it is open; nothing here
/// needs a server, so it runs on Firebase's free plan.
abstract final class LiveAlerts {
  /// New and started tasks. [gone] receives the ids of running tasks that
  /// left the board - the caller checks History to see who finished them.
  static List<LiveAlert> tasks(
    List<RoverTask> before,
    List<RoverTask> after,
    String myId, {
    void Function(String taskId)? gone,
  }) {
    final old = {for (final t in before) t.id: t};
    final alerts = <LiveAlert>[];
    for (final t in after) {
      final was = old.remove(t.id);
      if (was == null) {
        if (t.createdById != myId) {
          alerts.add(LiveAlert('taskCreated', 'New task: ${t.title}'));
        }
      } else if (was.status == TaskStatus.pending &&
          t.status == TaskStatus.inProgress &&
          t.startedById != myId) {
        alerts.add(
          LiveAlert('taskStarted', '${t.startedByName} started "${t.title}"'),
        );
      }
    }
    for (final t in old.values) {
      if (t.status == TaskStatus.inProgress) gone?.call(t.id);
    }
    return alerts;
  }

  static LiveAlert? completed(RoverTask record, String myId) =>
      record.endedById == myId
      ? null
      : LiveAlert(
          'taskCompleted',
          '${record.endedByName} completed "${record.title}"',
        );

  /// Important or pinned notes that were not in the previous snapshot.
  static List<LiveAlert> notes(
    List<Note> before,
    List<Note> after,
    String myId,
  ) {
    final known = {for (final n in before) n.id};
    final newest = before.isEmpty ? null : before.first.createdAt;
    return [
      for (final n in after)
        if (!known.contains(n.id) &&
            n.authorId != myId &&
            (n.important || n.pinned) &&
            (newest == null ||
                n.createdAt == null ||
                n.createdAt!.isAfter(newest)))
          LiveAlert('importantNotes', '${n.authorName}: ${n.title}'),
    ];
  }
}
