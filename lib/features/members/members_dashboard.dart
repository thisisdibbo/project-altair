import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/dashboard_scaffold.dart';
import '../tasks/task_widgets.dart';
import 'member_editor_sheet.dart';

/// One directory screen, used three times: Team Leads (laid out like the
/// team's panel chart),
/// Senior Members and Junior Members (grouped by sub-team). Each group
/// reads its own Firestore collection, so they are never mixed.
class MembersDashboard extends ConsumerStatefulWidget {
  const MembersDashboard({super.key, required this.group});

  final MemberGroup group;

  @override
  ConsumerState<MembersDashboard> createState() => _MembersDashboardState();
}

class _Section {
  _Section(this.id, this.name);

  final String id;
  final String name;
  final List<Member> members = [];
}

class _MembersDashboardState extends ConsumerState<MembersDashboard> {
  final _search = TextEditingController();
  String _query = '';
  String? _subTeamId;
  String? _expandedMember;
  final Set<String> _openSections = {};

  MemberGroup get group => widget.group;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Member m, Map<String, String> teamNames) {
    if (_subTeamId != null && m.subTeamId != _subTeamId) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final team = teamNames[m.subTeamId] ?? m.subTeamName;
    return m.fullName.toLowerCase().contains(q) ||
        m.position.toLowerCase().contains(q) ||
        team.toLowerCase().contains(q) ||
        m.phone.contains(q);
  }

  List<_Section> _sections(List<Member> members, List<SubTeam> teams) {
    final sections = <String, _Section>{
      for (final t in teams) t.id: _Section(t.id, t.name),
    };
    for (final m in members) {
      sections
          .putIfAbsent(
            m.subTeamId,
            () => _Section(
              m.subTeamId,
              m.subTeamName.isEmpty ? 'Unassigned' : m.subTeamName,
            ),
          )
          .members
          .add(m);
    }
    return sections.values.toList();
  }

  void _toggleMember(String id) {
    Haptics.select();
    setState(() => _expandedMember = _expandedMember == id ? null : id);
  }

  Widget _card(Member m, int index, Map<String, String> teamNames, bool manage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Appear(
        key: ValueKey(m.id),
        index: index,
        child: _withBar(
          m,
          MemberCard(
            member: m,
            group: group,
            subTeamName: teamNames[m.subTeamId] ?? m.subTeamName,
            expanded: _expandedMember == m.id,
            canManage: manage,
            onToggle: () => _toggleMember(m.id),
          ),
        ),
      ),
    );
  }

  /// Team Leads cards carry the panel chart's orange bar: solid for leads,
  /// dashed for executives.
  Widget _withBar(Member m, Widget card) => group == MemberGroup.teamLeads
      ? _Marked(dashed: m.tier == 'executive', child: card)
      : card;

  /// By the "Order in the list" number (people without one last), then
  /// by name.
  static List<Member> _ordered(Iterable<Member> members) {
    int rank(Member m) => m.order > 0 ? m.order : 1000;
    return [...members]..sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0
          ? r
          : a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
  }

  /// The Team Leads page in the same shape as the panel chart: the Team
  /// Lead, then each wing as a tree of who sits under whom.
  List<Widget> _panel(
    List<Member> all,
    Map<String, String> teamNames,
    bool manage,
  ) {
    final sorted = _ordered(all);
    final wingIds = {for (final w in leadWings) w.$1};
    final central = [
      for (final m in sorted)
        if (m.tier == 'lead') m,
    ];
    final unplaced = [
      for (final m in sorted)
        if (m.tier != 'lead' && !wingIds.contains(m.wing)) m,
    ];
    var n = 0;
    return [
      if (central.isNotEmpty) ...[
        const _Heading('TEAM LEAD'),
        for (final m in central) _card(m, n++, teamNames, manage),
      ],
      for (final (id, name) in leadWings)
        ?_wing(id, name, sorted, teamNames, manage),
      if (unplaced.isNotEmpty) ...[
        const _Heading('NOT IN A WING YET'),
        for (final m in unplaced) _card(m, n++, teamNames, manage),
      ],
    ];
  }

  Widget? _wing(
    String id,
    String name,
    List<Member> sorted,
    Map<String, String> teamNames,
    bool manage,
  ) {
    final inWing = [
      for (final m in sorted)
        if (m.tier != 'lead' && m.wing == id) m,
    ];
    if (inWing.isEmpty) return null;
    final ids = {for (final m in inWing) m.id};
    final under = <String, List<Member>>{};
    for (final m in inWing) {
      final parent = ids.contains(m.reportsTo) ? m.reportsTo : '';
      under.putIfAbsent(parent, () => []).add(m);
    }
    final placed = <String>{};
    var n = 0;
    void place(Member m, List<Widget> out) {
      if (!placed.add(m.id)) return;
      out.add(_card(m, n++, teamNames, manage));
      final below = <Widget>[];
      for (final c in under[m.id] ?? const <Member>[]) {
        place(c, below);
      }
      if (below.isNotEmpty) out.add(_Branch(children: below));
    }

    final rows = <Widget>[];
    for (final m in under[''] ?? const <Member>[]) {
      place(m, rows);
    }
    // Anyone left (two people set under each other) still gets shown.
    for (final m in inWing) {
      place(m, rows);
    }
    final key = 'wing-$id';
    return _SubTeamSection(
      key: ValueKey(key),
      name: name,
      count: inWing.length,
      // On this page sections start open; the set holds the closed ones.
      open: !_openSections.contains(key),
      onToggle: () {
        Haptics.select();
        setState(() {
          if (!_openSections.remove(key)) _openSections.add(key);
        });
      },
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final manage = perms?.manageMembers ?? false;
    final state = ref.watch(membersProvider(group));
    final teams = ref.watch(subTeamsProvider).value ?? const <SubTeam>[];
    final teamNames = {for (final t in teams) t.id: t.name};
    final all = state.value ?? const <Member>[];
    final shown = all.where((m) => _matches(m, teamNames)).toList();
    final filtering = _query.trim().isNotEmpty || _subTeamId != null;
    final myId = perms?.user.id;
    final canAdd =
        manage ||
        ((perms?.ownsCardIn(group) ?? false) &&
            state.value != null &&
            !all.any((m) => m.id == myId));

    final Widget list;
    if (state.value == null && state.isLoading) {
      list = const SliverToBoxAdapter(child: SkeletonList(height: 76));
    } else if (state.value == null && state.hasError) {
      list = SliverToBoxAdapter(
        child: ErrorState(
          message: friendlyError(state.error!),
          onRetry: () => ref.invalidate(membersProvider(group)),
        ),
      );
    } else if (all.isEmpty && (!group.groupedBySubTeam || teams.isEmpty)) {
      list = SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.groups_2_outlined,
          title: 'No ${group.title.toLowerCase()} yet',
          message: canAdd
              ? 'Tap the orange + to add the first profile.'
              : 'Profiles appear here once a team lead adds them.',
        ),
      );
    } else if (group.plainList) {
      final ordered = _ordered(shown);
      list = ordered.isEmpty
          ? const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No one found',
                message: 'Try a different name.',
              ),
            )
          : SliverList.builder(
              itemCount: ordered.length,
              itemBuilder: (context, i) =>
                  _card(ordered[i], i, teamNames, manage),
            );
    } else if (!group.groupedBySubTeam) {
      list = shown.isEmpty
          ? const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No one found',
                message: 'Try a different name or sub-team.',
              ),
            )
          // While searching or filtering, matches are listed plainly.
          : filtering
          ? SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) =>
                  _card(shown[i], i, teamNames, manage),
            )
          : SliverList.list(children: _panel(all, teamNames, manage));
    } else {
      final sections = _sections(shown, teams)
          .where(
            (s) =>
                (_subTeamId == null || s.id == _subTeamId) &&
                (!filtering || s.members.isNotEmpty),
          )
          .toList();
      list = sections.isEmpty
          ? const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No one found',
                message: 'Try a different name or sub-team.',
              ),
            )
          : SliverList.builder(
              itemCount: sections.length,
              itemBuilder: (context, i) {
                final s = sections[i];
                final open = filtering || _openSections.contains(s.id);
                return _SubTeamSection(
                  name: s.name,
                  count: s.members.length,
                  open: open,
                  onToggle: () {
                    Haptics.select();
                    setState(() {
                      if (!_openSections.remove(s.id)) _openSections.add(s.id);
                    });
                  },
                  children: [
                    for (var j = 0; j < s.members.length; j++)
                      _card(s.members[j], j, teamNames, manage),
                  ],
                );
              },
            );
    }

    return DashboardScaffold(
      index: 3 + group.index,
      title: group.title.toUpperCase().replaceFirst(' ', '\n'),
      facts: state.value == null
          ? const []
          : [
              (
                '${all.length}',
                group.groupedBySubTeam
                    ? 'Members'
                    : group == MemberGroup.teamLeads
                    ? 'Leads'
                    : group.title,
              ),
              if (group.groupedBySubTeam) ('${teams.length}', 'Sub-teams'),
              if (filtering) ('${shown.length}', 'Shown'),
            ],
      onRefresh: () async => ref.invalidate(membersProvider(group)),
      fab: canAdd
          ? AltairFab(
              tooltip: manage
                  ? 'Add ${group.singular.toLowerCase()}'
                  : 'Add my profile',
              onTap: () => showMemberEditor(
                context,
                group: group,
                selfId: manage ? null : myId,
              ),
            )
          : null,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchField(
                controller: _search,
                hint: 'Search ${group.title.toLowerCase()}',
                onChanged: (v) => setState(() => _query = v),
              ),
              if (teams.isNotEmpty && !group.plainList) ...[
                const SizedBox(height: 12),
                PillRow(
                  children: [
                    FilterPill(
                      label: 'All',
                      selected: _subTeamId == null,
                      onTap: () => setState(() => _subTeamId = null),
                    ),
                    for (final t in teams)
                      FilterPill(
                        label: t.name,
                        selected: _subTeamId == t.id,
                        onTap: () => setState(() => _subTeamId = t.id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        list,
      ],
    );
  }
}

/// People who sit under the card above, indented behind a thin line.
class _Branch extends StatelessWidget {
  const _Branch({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 12),
    padding: const EdgeInsets.only(left: 10),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: context.palette.line, width: 1.5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _Marked extends StatelessWidget {
  const _Marked({required this.dashed, required this.child});

  final bool dashed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(padding: const EdgeInsets.only(left: 10), child: child),
      Positioned(
        left: 0,
        top: 6,
        bottom: 6,
        width: 3.5,
        child: CustomPaint(
          painter: _BarPainter(context.palette.accent, dashed),
        ),
      ),
    ],
  );
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.color, this.dashed);

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = Radius.circular(size.width / 2);
    if (!dashed) {
      canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), paint);
      return;
    }
    const dash = 7.0;
    const gap = 5.0;
    for (var y = 0.0; y < size.height; y += dash + gap) {
      final h = size.height - y < dash ? size.height - y : dash;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, y, size.width, h), r),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.color != color || old.dashed != dashed;
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
    child: Text(text, style: T.label(context)),
  );
}

/// Expandable sub-team (or wing) header with its member count.
class _SubTeamSection extends StatelessWidget {
  const _SubTeamSection({
    super.key,
    required this.name,
    required this.count,
    required this.open,
    required this.onToggle,
    required this.children,
  });

  final String name;
  final int count;
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PressScale(
          scale: 0.985,
          haptic: false,
          onTap: onToggle,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: p.surfaceHigh.withValues(alpha: p.isDark ? 0.6 : 1),
              border: Border.all(
                color: open ? p.accent.withValues(alpha: 0.5) : p.line,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: p.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.title(
                      context,
                    ).copyWith(fontSize: 14, letterSpacing: 2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: p.accent.withValues(alpha: 0.16),
                  ),
                  child: Text(
                    '$count',
                    style: T.mono(context, size: 12.5, color: p.accentText),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 24,
                    color: p.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !open
              ? const SizedBox(width: double.infinity)
              : children.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 16),
                  child: Text(
                    'No members in this sub-team yet.',
                    style: T.small(context),
                  ),
                )
              : Column(children: children),
        ),
      ],
    );
  }
}

/// Compact profile card that expands to full contact details.
class MemberCard extends ConsumerWidget {
  const MemberCard({
    super.key,
    required this.member,
    required this.group,
    required this.subTeamName,
    required this.expanded,
    required this.canManage,
    required this.onToggle,
  });

  final Member member;
  final MemberGroup group;
  final String subTeamName;
  final bool expanded;
  final bool canManage;
  final VoidCallback onToggle;

  String get _position =>
      member.position.isEmpty ? group.singular : member.position;

  Future<void> _open(
    BuildContext context,
    Future<bool> Function() action,
    String failure,
  ) async {
    final ok = await action();
    if (!ok && context.mounted) showToast(context, failure, error: true);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this profile?',
      message:
          '${member.fullName} will be removed from ${group.title} '
          'for everyone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(teamRepositoryProvider)
          .deleteMember(group, member.id, label: member.fullName);
      ref.read(photoRepositoryProvider).delete(member.photoUrl);
      if (context.mounted) showToast(context, 'Profile deleted');
    } catch (e) {
      if (context.mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _promote(BuildContext context, WidgetRef ref) async {
    final to = await showOptionsSheet<MemberGroup>(
      context,
      title: 'Promote ${member.fullName} to',
      options: [
        for (final g in MemberGroup.values.reversed)
          if (!g.plainList && g.index < group.index) Option(g, g.singular),
      ],
    );
    if (to == null || !context.mounted) return;
    try {
      await ref.read(teamRepositoryProvider).promoteMember(group, to, member);
      if (context.mounted) showToast(context, 'Promoted to ${to.singular}');
    } catch (e) {
      if (context.mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final perms = ref.watch(permissionsProvider);
    final mine =
        member.id == perms?.user.id && (perms?.ownsCardIn(group) ?? false);
    final canPromote = perms?.canPromoteFrom(group) ?? false;
    return FrostCard(
      highlight: expanded,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          PressScale(
            scale: 0.99,
            haptic: false,
            onTap: onToggle,
            child: Row(
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: expanded ? 0.0 : 1.0,
                  child: Avatar(
                    name: member.fullName,
                    url: member.photoUrl,
                    size: 46,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.strong(context).copyWith(fontSize: 15.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          _position,
                          if (subTeamName.isNotEmpty) subTeamName,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.small(context),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 24,
                    color: p.textFaint,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      const SizedBox(height: 6),
                      Avatar(
                        name: member.fullName,
                        url: member.photoUrl,
                        size: 112,
                        ring: true,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        member.fullName,
                        textAlign: TextAlign.center,
                        style: T.title(context).copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          Tag(_position, accent: true),
                          if (subTeamName.isNotEmpty)
                            Tag(subTeamName, icon: Icons.hub_outlined),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DetailRow('Phone', member.phone, mono: true),
                      DetailRow('WhatsApp', member.whatsapp, mono: true),
                      DetailRow('Messenger', member.messengerLink),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: _ContactAction(
                              icon: Icons.call_rounded,
                              label: 'Call now',
                              primary: true,
                              onTap: () => _open(
                                context,
                                () => Contact.call(member.phone),
                                'Could not open the phone dialer.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ContactAction(
                              icon: Icons.chat_rounded,
                              label: 'WhatsApp',
                              onTap: () => _open(
                                context,
                                () => Contact.whatsApp(member.whatsapp),
                                'Could not open WhatsApp for this number.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ContactAction(
                              icon: Icons.forum_rounded,
                              label: 'Messenger',
                              onTap: () => _open(
                                context,
                                () => Contact.messenger(member.messengerLink),
                                'Could not open this Messenger link.',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (canManage || mine) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GhostButton(
                                label: 'Edit',
                                icon: Icons.edit_outlined,
                                compact: true,
                                onPressed: () => showMemberEditor(
                                  context,
                                  group: group,
                                  existing: member,
                                ),
                              ),
                            ),
                            if (canManage) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: GhostButton(
                                  label: 'Delete',
                                  icon: Icons.delete_outline_rounded,
                                  compact: true,
                                  danger: true,
                                  onPressed: () => _delete(context, ref),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (canPromote) ...[
                        const SizedBox(height: 10),
                        GhostButton(
                          label: 'Promote',
                          icon: Icons.arrow_upward_rounded,
                          compact: true,
                          accent: true,
                          onPressed: () => _promote(context, ref),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = primary ? p.onAccent : p.accentText;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: primary ? p.accent : p.accent.withValues(alpha: 0.12),
          border: Border.all(
            color: primary
                ? Colors.white.withValues(alpha: 0.25)
                : p.accent.withValues(alpha: 0.5),
          ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: p.accent.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
