import 'models/models.dart';

/// What the signed-in user may do. The same rules are enforced on the
/// server in firestore.rules - this class only decides which buttons to show.
class Permissions {
  const Permissions(this.user);

  final AppUser user;

  Role get role => user.role;

  bool get openAdminPanel => role.isAdmin;
  bool get manageUsers => role.isAdmin;
  bool get manageSubTeams => role.isAdmin;
  bool get viewActivity => role.isAdmin;

  bool get createTasks => true;
  bool get editTasks => role.isLead;
  bool get editHistory => role.isAdmin;

  bool canStart(RoverTask t) =>
      role.isLead || t.responsibleId == user.id || t.createdById == user.id;

  bool canEnd(RoverTask t) =>
      role.isLead ||
      t.responsibleId == user.id ||
      t.startedById == user.id ||
      t.createdById == user.id;

  bool get createNotes => true;
  bool get pinNotes => role.isLead;
  bool canEditNote(Note n) => role.isAdmin || n.authorId == user.id;

  bool get manageMembers => role.isLead;

  /// Everyone except leads (seniors, juniors, advisors, moderators) keeps
  /// one card of their own, in the directory that matches their role.
  bool ownsCardIn(MemberGroup group) => !role.isLead && group.role == role;

  /// Only a Super Admin moves a card up to a higher directory.
  bool canPromoteFrom(MemberGroup group) =>
      role.isAdmin && group.groupedBySubTeam;

  bool get manageInventory => role.isLead;
  bool get manageEvents => role.isLead;
}
