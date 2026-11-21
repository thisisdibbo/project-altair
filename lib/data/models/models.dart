import 'package:cloud_firestore/cloud_firestore.dart';

import 'extras_models.dart';

typedef Doc = DocumentSnapshot<Map<String, dynamic>>;

String _str(Object? v) => v is String ? v : '';
DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

enum Role {
  superAdmin('superAdmin', 'Super Admin'),
  teamLead('teamLead', 'Team Lead'),
  senior('senior', 'Senior Member'),
  junior('junior', 'Junior Member'),
  advisor('advisor', 'Advisor'),
  moderator('moderator', 'Moderator');

  const Role(this.key, this.label);

  final String key;
  final String label;

  bool get isAdmin => this == Role.superAdmin;
  bool get isLead => this == Role.superAdmin || this == Role.teamLead;

  static Role parse(Object? v) =>
      Role.values.firstWhere((r) => r.key == v, orElse: () => Role.junior);
}

class AppUser {
  const AppUser({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.role,
    this.position = '',
    this.subTeamId = '',
    this.subTeamName = '',
    this.photoUrl = '',
    this.disabled = false,
    this.mustChangePassword = false,
  });

  /// Firebase account id. Never shown to members.
  final String id;

  /// The User ID exactly as the administrator typed it.
  final String userId;
  final String fullName;
  final Role role;
  final String position;
  final String subTeamId;
  final String subTeamName;
  final String photoUrl;
  final bool disabled;

  /// True while the member still uses a password chosen by an administrator.
  final bool mustChangePassword;

  factory AppUser.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      id: doc.id,
      userId: _str(d['userId']).isEmpty ? doc.id : _str(d['userId']),
      fullName: _str(d['fullName']),
      role: Role.parse(d['role']),
      position: _str(d['position']),
      subTeamId: _str(d['subTeamId']),
      subTeamName: _str(d['subTeamName']),
      photoUrl: _str(d['photoUrl']),
      disabled: d['disabled'] == true,
      mustChangePassword: d['mustChangePassword'] == true,
    );
  }
}

enum TaskStatus {
  pending('PENDING'),
  inProgress('IN PROGRESS'),
  completed('COMPLETED');

  const TaskStatus(this.label);

  final String label;

  static TaskStatus parse(Object? v) =>
      TaskStatus.values.asNameMap()[v] ?? TaskStatus.pending;
}

const taskPriorities = <(String, String)>[
  ('', 'None'),
  ('low', 'Low'),
  ('normal', 'Normal'),
  ('high', 'High'),
  ('critical', 'Critical'),
];

class RoverTask {
  const RoverTask({
    required this.id,
    required this.title,
    required this.description,
    required this.responsibleId,
    required this.responsibleName,
    required this.subTeamId,
    required this.subTeamName,
    required this.priority,
    required this.status,
    required this.startedById,
    required this.startedByName,
    required this.endedById,
    required this.endedByName,
    required this.createdById,
    required this.createdByName,
    this.scheduledAt,
    this.dueAt,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.checklist = const [],
  });

  final String id;
  final String title;
  final String description;
  final String responsibleId;
  final String responsibleName;
  final String subTeamId;
  final String subTeamName;
  final String priority;
  final TaskStatus status;
  final String startedById;
  final String startedByName;
  final String endedById;
  final String endedByName;
  final String createdById;
  final String createdByName;
  final DateTime? scheduledAt;

  /// Optional deadline. The card turns red once it has passed.
  final DateTime? dueAt;

  /// Small steps to tick off. Kept inside the task, so it moves to History
  /// with it.
  final List<ChecklistItem> checklist;

  /// The server's clock at the moment START was pressed.
  final DateTime? startedAt;

  /// The server's clock at the moment END TASK was confirmed.
  final DateTime? endedAt;
  final DateTime? createdAt;

  Duration? get totalDuration => startedAt != null && endedAt != null
      ? endedAt!.difference(startedAt!)
      : null;

  factory RoverTask.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return RoverTask(
      id: doc.id,
      title: _str(d['title']),
      description: _str(d['description']),
      responsibleId: _str(d['responsibleId']),
      responsibleName: _str(d['responsibleName']),
      subTeamId: _str(d['subTeamId']),
      subTeamName: _str(d['subTeamName']),
      priority: _str(d['priority']),
      status: TaskStatus.parse(d['status']),
      startedById: _str(d['startedById']),
      startedByName: _str(d['startedByName']),
      endedById: _str(d['endedById']),
      endedByName: _str(d['endedByName']),
      createdById: _str(d['createdById']),
      createdByName: _str(d['createdByName']),
      scheduledAt: _date(d['scheduledAt']),
      dueAt: _date(d['dueAt']),
      checklist: ChecklistItem.listFrom(d['checklist']),
      startedAt: _date(d['startedAt']),
      endedAt: _date(d['endedAt']),
      createdAt: _date(d['createdAt']),
    );
  }
}

/// The editable part of a task (the Add Task / Edit Task form).
class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.responsibleId,
    required this.responsibleName,
    required this.subTeamId,
    required this.subTeamName,
    required this.scheduledAt,
    required this.priority,
    this.dueAt,
  });

  final String title;
  final String description;
  final String responsibleId;
  final String responsibleName;
  final String subTeamId;
  final String subTeamName;
  final DateTime? scheduledAt;
  final String priority;
  final DateTime? dueAt;

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'responsibleId': responsibleId,
    'responsibleName': responsibleName,
    'subTeamId': subTeamId,
    'subTeamName': subTeamName,
    'scheduledAt': scheduledAt == null
        ? null
        : Timestamp.fromDate(scheduledAt!),
    'priority': priority,
    'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt!),
  };
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.category,
    required this.pinned,
    required this.important,
    this.createdAt,
    this.updatedAt,
    this.done = false,
    this.doneById = '',
    this.doneByName = '',
  });

  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String category;
  final bool pinned;
  final bool important;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Ticked off with the Done button, and by whom.
  final bool done;
  final String doneById;
  final String doneByName;

  bool get edited =>
      createdAt != null &&
      updatedAt != null &&
      updatedAt!.difference(createdAt!).inSeconds > 5;

  factory Note.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Note(
      id: doc.id,
      title: _str(d['title']),
      content: _str(d['content']),
      authorId: _str(d['authorId']),
      authorName: _str(d['authorName']),
      authorPhotoUrl: _str(d['authorPhotoUrl']),
      category: _str(d['category']),
      pinned: d['pinned'] == true,
      important: d['important'] == true,
      done: d['done'] == true,
      doneById: _str(d['doneById']),
      doneByName: _str(d['doneByName']),
      createdAt: _date(d['createdAt']),
      updatedAt: _date(d['updatedAt']),
    );
  }
}

/// Each member directory is kept in its own collection. The order here is
/// the order of the pages in the app.
enum MemberGroup {
  moderators('moderators', 'Moderators', 'Moderator'),
  advisors('advisors', 'Advisors', 'Advisor'),
  teamLeads('teamLeads', 'Team Leads', 'Team Lead'),
  seniorMembers('seniorMembers', 'Senior Members', 'Senior Member'),
  juniorMembers('juniorMembers', 'Junior Members', 'Junior Member');

  const MemberGroup(this.collection, this.title, this.singular);

  final String collection;
  final String title;
  final String singular;

  /// Senior and junior members are listed by sub-team.
  bool get groupedBySubTeam =>
      this == MemberGroup.seniorMembers || this == MemberGroup.juniorMembers;

  /// Advisors and moderators: one ordered list, no sub-teams.
  bool get plainList =>
      this == MemberGroup.advisors || this == MemberGroup.moderators;

  /// The account role that goes with this directory.
  Role? get role => switch (this) {
    MemberGroup.teamLeads => Role.teamLead,
    MemberGroup.seniorMembers => Role.senior,
    MemberGroup.juniorMembers => Role.junior,
    MemberGroup.advisors => Role.advisor,
    MemberGroup.moderators => Role.moderator,
  };
}

class Member {
  const Member({
    required this.id,
    required this.fullName,
    required this.position,
    required this.subTeamId,
    required this.subTeamName,
    required this.phone,
    required this.whatsapp,
    required this.messengerLink,
    required this.photoUrl,
    this.tier = '',
    this.wing = '',
    this.reportsTo = '',
    this.order = 0,
  });

  final String id;
  final String fullName;
  final String position;
  final String subTeamId;
  final String subTeamName;
  final String phone;
  final String whatsapp;
  final String messengerLink;
  final String photoUrl;

  /// Team Leads page only: 'lead' (the central Team Lead), 'executive',
  /// or '' (a lead).
  final String tier;

  /// Team Leads page only: 'management', 'technical' or 'scientific'.
  final String wing;

  /// Team Leads page only: the card this person sits under, '' = top of
  /// the wing.
  final String reportsTo;

  /// Team Leads page only: place among the people under the same card
  /// (1 = first, 0 = not set and shown last).
  final int order;

  factory Member.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Member(
      id: doc.id,
      fullName: _str(d['fullName']),
      position: _str(d['position']),
      subTeamId: _str(d['subTeamId']),
      subTeamName: _str(d['subTeamName']),
      phone: _str(d['phone']),
      whatsapp: _str(d['whatsapp']),
      messengerLink: _str(d['messengerLink']),
      photoUrl: _str(d['photoUrl']),
      tier: _str(d['tier']),
      wing: _str(d['wing']),
      reportsTo: _str(d['reportsTo']),
      order: d['order'] is num ? (d['order'] as num).toInt() : 0,
    );
  }
}

/// The wings of the Team Leads page, in the order they are shown.
const leadWings = [
  ('management', 'Management Wing'),
  ('technical', 'Technical Wing'),
  ('scientific', 'Scientific Wing'),
];

class SubTeam {
  const SubTeam({required this.id, required this.name, required this.order});

  final String id;
  final String name;
  final int order;

  factory SubTeam.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final order = d['order'];
    return SubTeam(
      id: doc.id,
      name: _str(d['name']),
      order: order is num ? order.toInt() : 0,
    );
  }
}

class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.type,
    required this.message,
    required this.actorName,
    this.createdAt,
  });

  final String id;
  final String type;
  final String message;
  final String actorName;
  final DateTime? createdAt;

  factory ActivityLog.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return ActivityLog(
      id: doc.id,
      type: _str(d['type']),
      message: _str(d['message']),
      actorName: _str(d['actorName']),
      createdAt: _date(d['createdAt']),
    );
  }
}
