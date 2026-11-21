import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/sub_page.dart';

/// Sub-teams are configured here and used everywhere else: task forms,
/// filters and the grouped member directories.
class AdminSubTeamsScreen extends ConsumerStatefulWidget {
  const AdminSubTeamsScreen({super.key});

  @override
  ConsumerState<AdminSubTeamsScreen> createState() =>
      _AdminSubTeamsScreenState();
}

class _AdminSubTeamsScreenState extends ConsumerState<AdminSubTeamsScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _try(Future<Object?> Function() action, [String? done]) async {
    try {
      await action();
      if (mounted && done != null) showToast(context, done);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _add(List<SubTeam> teams) async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (teams.any((t) => t.name.toLowerCase() == name.toLowerCase())) {
      showToast(context, 'That sub-team already exists.', error: true);
      return;
    }
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    final order = teams.isEmpty ? 0 : teams.last.order + 1;
    _name.clear();
    await _try(
      () => ref.read(teamRepositoryProvider).addSubTeam(name, order, uid),
      'Sub-team added',
    );
  }

  Future<void> _rename(SubTeam team) async {
    final name = await showAltairSheet<String>(
      context,
      builder: (_) => _RenameSheet(initial: team.name),
    );
    if (name == null || name == team.name) return;
    await _try(
      () => ref.read(teamRepositoryProvider).renameSubTeam(team.id, name),
      'Sub-team renamed',
    );
  }

  Future<void> _delete(SubTeam team) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete "${team.name}"?',
      message:
          'Members and tasks already assigned to it keep their records, '
          'but it can no longer be chosen.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok) return;
    await _try(
      () => ref
          .read(teamRepositoryProvider)
          .deleteSubTeam(team.id, label: team.name),
      'Sub-team deleted',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = ref.watch(subTeamsProvider);
    final teams = state.value ?? const <SubTeam>[];
    final repo = ref.read(teamRepositoryProvider);
    return SubPage(
      title: 'SUB-TEAMS',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AltairTextField(
                controller: _name,
                label: 'New sub-team',
                hint: 'e.g. Mechanical',
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _add(teams),
              ),
            ),
            const SizedBox(width: 10),
            PrimaryButton(
              label: 'Add',
              icon: Icons.add_rounded,
              expand: false,
              onPressed: () => _add(teams),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (state.value == null && state.isLoading)
          const SkeletonList(height: 62, count: 4)
        else if (teams.isEmpty)
          const EmptyState(
            icon: Icons.hub_outlined,
            title: 'No sub-teams yet',
            message:
                'Add the team\'s sub-teams, for example Mechanical, '
                'Electrical, Software and Autonomous.',
          )
        else
          for (var i = 0; i < teams.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FrostCard(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        teams[i].name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.title(
                          context,
                        ).copyWith(fontSize: 14, letterSpacing: 1.8),
                      ),
                    ),
                    RoundIconButton(
                      icon: Icons.arrow_upward_rounded,
                      size: 36,
                      tooltip: 'Move up',
                      color: i == 0 ? p.textFaint : null,
                      onTap: i == 0
                          ? null
                          : () => _try(
                              () => repo.swapSubTeams(teams[i], teams[i - 1]),
                            ),
                    ),
                    const SizedBox(width: 6),
                    RoundIconButton(
                      icon: Icons.arrow_downward_rounded,
                      size: 36,
                      tooltip: 'Move down',
                      color: i == teams.length - 1 ? p.textFaint : null,
                      onTap: i == teams.length - 1
                          ? null
                          : () => _try(
                              () => repo.swapSubTeams(teams[i], teams[i + 1]),
                            ),
                    ),
                    const SizedBox(width: 6),
                    RoundIconButton(
                      icon: Icons.edit_outlined,
                      size: 36,
                      tooltip: 'Rename',
                      onTap: () => _rename(teams[i]),
                    ),
                    const SizedBox(width: 6),
                    RoundIconButton(
                      icon: Icons.delete_outline_rounded,
                      size: 36,
                      tooltip: 'Delete',
                      color: p.ember,
                      onTap: () => _delete(teams[i]),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.initial});

  final String initial;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SheetTitle('Rename sub-team'),
      AltairTextField(
        controller: _name,
        label: 'Name',
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
      ),
      SheetActions(
        confirmLabel: 'Save',
        onConfirm: () {
          final name = _name.text.trim();
          if (name.isNotEmpty) Navigator.of(context).pop(name);
        },
      ),
    ],
  );
}
