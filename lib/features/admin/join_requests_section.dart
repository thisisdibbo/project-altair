import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/sub_page.dart';

/// People who asked for an account. A Super Admin checks the picture and
/// student ID, then approves (account and profile card are made together)
/// or rejects.
class JoinRequestsSection extends ConsumerWidget {
  const JoinRequestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests =
        ref.watch(pendingJoinRequestsProvider).value ?? const <JoinRequest>[];
    return SectionCard(
      title: requests.isEmpty
          ? 'Join requests'
          : 'Join requests · ${requests.length} waiting',
      children: [
        if (requests.isEmpty)
          const SettingRow(
            icon: Icons.how_to_reg_outlined,
            title: 'No one is waiting',
            subtitle:
                'People can request an account from the sign-in screen. '
                'Their requests appear here for you to approve.',
          ),
        for (final r in requests)
          SettingRow(
            icon: Icons.person_add_alt_1_outlined,
            title: r.fullName,
            subtitle: [
              joinGroupName(r.group),
              if (r.subTeamName.isNotEmpty) r.subTeamName,
              'ID ${r.studentId}',
            ].join(' · '),
            onTap: () => showAltairSheet<void>(
              context,
              builder: (_) => _Review(request: r),
            ),
          ),
      ],
    );
  }
}

class _Review extends ConsumerStatefulWidget {
  const _Review({required this.request});

  final JoinRequest request;

  @override
  ConsumerState<_Review> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<_Review> {
  late MemberGroup _group = widget.request.group;
  late String _subTeamId = widget.request.subTeamId;
  late String _subTeamName = widget.request.subTeamName;
  late final _photo = widget.request.photoBytes;
  bool _busy = false;

  Future<void> _pickGroup() async {
    final picked = await showOptionsSheet<MemberGroup>(
      context,
      title: 'Add them as',
      selected: _group,
      options: [for (final g in joinGroups) Option(g, joinGroupName(g))],
    );
    if (picked != null) setState(() => _group = picked);
  }

  Future<void> _pickSubTeam() async {
    final teams = ref.read(subTeamsProvider).value ?? const <SubTeam>[];
    final picked = await showOptionsSheet<SubTeam>(
      context,
      title: 'Sub-team',
      selected: teams.where((t) => t.id == _subTeamId).firstOrNull,
      options: [for (final t in teams) Option(t, t.name)],
    );
    if (picked == null) return;
    setState(() {
      _subTeamId = picked.id;
      _subTeamName = picked.name;
    });
  }

  Future<void> _approve() async {
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(joinRequestsProvider)
          .approve(
            widget.request,
            group: _group,
            subTeamId: _group.plainList ? '' : _subTeamId,
            subTeamName: _group.plainList ? '' : _subTeamName,
            admin: me,
          );
      if (!mounted) return;
      showToast(
        context,
        '${widget.request.fullName} is in. Their card is on the '
        '${_group.title} page.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _reject() async {
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    final sure = await confirmDialog(
      context,
      title: 'Reject this request?',
      message:
          '${widget.request.fullName} will see that the request was not '
          'approved, and can delete it and try again.',
      confirmLabel: 'Reject',
      danger: true,
    );
    if (!sure || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(joinRequestsProvider).reject(widget.request, me);
      if (!mounted) return;
      showToast(context, 'Request rejected');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final at = r.createdAt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(
          r.fullName,
          subtitle: at == null ? null : 'Asked on ${formatDateTime(at)}',
        ),
        Center(
          child: Avatar(name: r.fullName, image: _photo, size: 132, ring: true),
        ),
        const SizedBox(height: 16),
        _Detail('User ID', r.userId),
        _Detail(r.group.plainList ? 'Staff ID' : 'Student ID', r.studentId),
        if (r.position.isNotEmpty) _Detail('Position', r.position),
        _Detail('Phone', r.phone),
        if (r.whatsapp != r.phone) _Detail('WhatsApp', r.whatsapp),
        _Detail('Messenger', r.messengerLink),
        const SizedBox(height: 14),
        PickerField(
          label: 'Add them as',
          icon: Icons.groups_outlined,
          value: joinGroupName(_group),
          onTap: _busy ? null : _pickGroup,
        ),
        if (!_group.plainList) ...[
          const SizedBox(height: 14),
          PickerField(
            label: 'Sub-team',
            icon: Icons.hub_outlined,
            value: _subTeamName.isEmpty ? null : _subTeamName,
            placeholder: 'Choose a sub-team',
            onTap: _busy ? null : _pickSubTeam,
          ),
        ],
        const SizedBox(height: 10),
        Center(
          child: GhostButton(
            label: 'Reject',
            icon: Icons.block_rounded,
            expand: false,
            compact: true,
            onPressed: _busy ? null : _reject,
          ),
        ),
        SheetActions(confirmLabel: 'Approve', busy: _busy, onConfirm: _approve),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 96, child: Text(label, style: T.small(context))),
        Expanded(
          child: SelectableText(
            value.isEmpty ? '-' : value,
            style: T.body(context),
          ),
        ),
      ],
    ),
  );
}
