import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../history/history_dashboard.dart';
import '../hub/calendar_screen.dart';
import '../shell/dashboard_scaffold.dart';
import 'due_line.dart';
import 'task_detail_screen.dart';
import 'task_editor_sheet.dart';
import 'task_widgets.dart';

/// ROVER OPERATIONS - the live board of what the team is working on.
class TasksDashboard extends ConsumerStatefulWidget {
  const TasksDashboard({super.key});

  @override
  ConsumerState<TasksDashboard> createState() => _TasksDashboardState();
}

class _TasksDashboardState extends ConsumerState<TasksDashboard> {
  bool _showCompleted = false;
  IdName? _subTeam;
  IdName? _member;

  bool _matches(RoverTask t) =>
      (_subTeam == null || t.subTeamId == _subTeam!.id) &&
      (_member == null || t.responsibleId == _member!.id);

  /// Running tasks first (longest running on top), then queued tasks in
  /// the order they are scheduled.
  List<RoverTask> _sorted(List<RoverTask> tasks) {
    final list = tasks.where(_matches).toList();
    final far = DateTime(9999);
    list.sort((a, b) {
      final ar = a.status == TaskStatus.inProgress;
      final br = b.status == TaskStatus.inProgress;
      if (ar != br) return ar ? -1 : 1;
      if (ar) return (a.startedAt ?? far).compareTo(b.startedAt ?? far);
      return (a.scheduledAt ?? a.createdAt ?? far).compareTo(
        b.scheduledAt ?? b.createdAt ?? far,
      );
    });
    return list;
  }

  Future<void> _pickSubTeam() async {
    final teams = ref.read(subTeamsProvider).value ?? const <SubTeam>[];
    final picked = await pickFilter(
      context,
      title: 'Filter by sub-team',
      allLabel: 'All sub-teams',
      selectedId: _subTeam?.id,
      items: [for (final t in teams) IdName(t.id, t.name)],
    );
    if (picked == null || !mounted) return;
    setState(() => _subTeam = picked.id.isEmpty ? null : picked);
  }

  Future<void> _pickMember() async {
    final users = ref.read(usersProvider).value ?? const <AppUser>[];
    final picked = await pickFilter(
      context,
      title: 'Filter by responsible member',
      allLabel: 'Everyone',
      selectedId: _member?.id,
      items: [for (final u in users) IdName(u.id, u.fullName)],
    );
    if (picked == null || !mounted) return;
    setState(() => _member = picked.id.isEmpty ? null : picked);
  }

  Future<void> _refresh() async {
    final uid = ref.read(uidProvider);
    if (uid != null) await ref.read(serverClockProvider).sync(uid);
    ref.invalidate(activeTasksProvider);
    if (_showCompleted) ref.invalidate(recentCompletedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final active = ref.watch(activeTasksProvider);
    final all = active.value ?? const <RoverTask>[];
    final running = all.where((t) => t.status == TaskStatus.inProgress).length;

    final Widget list;
    if (_showCompleted) {
      final completed = ref.watch(recentCompletedProvider);
      final items = (completed.value ?? const <RoverTask>[])
          .where(_matches)
          .toList();
      if (completed.value == null && completed.isLoading) {
        list = const SliverToBoxAdapter(child: SkeletonList(height: 96));
      } else if (completed.value == null && completed.hasError) {
        list = SliverToBoxAdapter(
          child: ErrorState(
            message: friendlyError(completed.error!),
            onRetry: () => ref.invalidate(recentCompletedProvider),
          ),
        );
      } else if (items.isEmpty) {
        list = const SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Nothing completed yet',
            message: 'Finished tasks appear here and in History.',
          ),
        );
      } else {
        list = SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => Appear(
            key: ValueKey(items[i].id),
            index: i,
            child: HistoryCard(task: items[i]),
          ),
        );
      }
    } else if (active.value == null && active.isLoading) {
      list = const SliverToBoxAdapter(child: SkeletonList(height: 168));
    } else if (active.value == null && active.hasError) {
      list = SliverToBoxAdapter(
        child: ErrorState(
          message: friendlyError(active.error!),
          onRetry: () => ref.invalidate(activeTasksProvider),
        ),
      );
    } else {
      final items = _sorted(all);
      if (items.isEmpty) {
        list = SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.precision_manufacturing_outlined,
            title: all.isEmpty ? 'No active operations' : 'No matching tasks',
            message: all.isEmpty
                ? 'Tap the orange + to add the first task.'
                : 'Change or clear the filters above.',
          ),
        );
      } else {
        list = SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => Appear(
            key: ValueKey(items[i].id),
            index: i,
            child: TaskCard(task: items[i], perms: perms),
          ),
        );
      }
    }

    return DashboardScaffold(
      index: 0,
      title: 'ROVER\nOPERATIONS',
      facts: active.value == null
          ? const []
          : [
              ('$running', 'In progress'),
              ('${all.length - running}', 'Queued'),
              ('${all.length}', 'On the board'),
            ],
      onRefresh: _refresh,
      fab: !_showCompleted && (perms?.createTasks ?? false)
          ? AltairFab(
              tooltip: 'Add task',
              onTap: () => showTaskEditor(context),
            )
          : null,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NextEventBanner(),
              Segmented<bool>(
                options: const [(false, 'Active'), (true, 'Completed')],
                selected: _showCompleted,
                onChanged: (v) => setState(() => _showCompleted = v),
              ),
              const SizedBox(height: 12),
              PillRow(
                children: [
                  FilterPill(
                    label: _subTeam?.name ?? 'Sub-team',
                    icon: Icons.hub_outlined,
                    selected: _subTeam != null,
                    onTap: _pickSubTeam,
                  ),
                  FilterPill(
                    label: _member?.name ?? 'Responsible member',
                    icon: Icons.person_outline_rounded,
                    selected: _member != null,
                    onTap: _pickMember,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        list,
      ],
    );
  }
}

class TaskCard extends ConsumerStatefulWidget {
  const TaskCard({super.key, required this.task, required this.perms});

  final RoverTask task;
  final Permissions? perms;

  @override
  ConsumerState<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<TaskCard> {
  bool _busy = false;

  RoverTask get task => widget.task;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      Haptics.medium();
      if (mounted) showToast(context, done);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    final me = widget.perms?.user;
    if (me == null) return;
    await _run(
      () => ref.read(taskRepositoryProvider).start(task.id, me),
      'Task started. The timer is running.',
    );
  }

  Future<void> _end() async {
    final me = widget.perms?.user;
    if (me == null) return;
    final ok = await confirmDialog(
      context,
      title: 'End this task?',
      message:
          '"${task.title}" will be marked completed and moved to History. '
          'The end time is recorded by the server.',
      confirmLabel: 'End task',
    );
    if (!ok || !mounted) return;
    await _run(
      () => ref.read(taskRepositoryProvider).end(task.id, me),
      'Task completed and saved to History.',
    );
  }

  Future<void> _more() async {
    final action = await showOptionsSheet<String>(
      context,
      title: task.title,
      options: const [
        Option('edit', 'Edit task'),
        Option('delete', 'Delete task'),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await showTaskEditor(context, existing: task);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Delete this task?',
      message:
          '"${task.title}" will be removed from the board for everyone. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(taskRepositoryProvider)
          .delete(task.id, label: task.title);
      if (mounted) showToast(context, 'Task deleted');
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  void _locked(String verb) => showToast(
    context,
    'Only the responsible member, the task creator or a team lead can '
    '$verb this task.',
    icon: Icons.lock_outline_rounded,
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final perms = widget.perms;
    final running = task.status == TaskStatus.inProgress;
    final canAct = perms != null &&
        (running ? perms.canEnd(task) : perms.canStart(task));

    return FrostCard(
      highlight: running,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(status: task.status),
              if (task.priority.isNotEmpty) ...[
                const SizedBox(width: 8),
                Tag(
                  priorityLabel(task.priority),
                  icon: Icons.flag_outlined,
                  accent: task.priority == 'high' ||
                      task.priority == 'critical',
                ),
              ],
              const Spacer(),
              if (perms?.editTasks ?? false)
                RoundIconButton(
                  icon: Icons.more_horiz_rounded,
                  size: 34,
                  tooltip: 'Edit or delete',
                  onTap: _more,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(task.title, style: T.title(context)),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: T.body(context),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 7,
            children: [
              MetaLine(
                Icons.person_outline_rounded,
                task.responsibleName.isEmpty
                    ? 'Unassigned'
                    : task.responsibleName,
              ),
              MetaLine(
                Icons.hub_outlined,
                task.subTeamName.isEmpty ? 'No sub-team' : task.subTeamName,
              ),
              MetaLine(
                Icons.schedule_rounded,
                running
                    ? 'Started ${formatFriendly(task.startedAt)}'
                    : 'Scheduled ${formatFriendly(task.scheduledAt)}',
              ),
              if (task.dueAt != null) DueLine(task.dueAt!),
              if (running && task.startedByName.isNotEmpty)
                MetaLine(
                  Icons.play_circle_outline_rounded,
                  'Started by ${task.startedByName}',
                ),
            ],
          ),
          TaskDetailsLink(task: task),
          const SizedBox(height: 14),
          Container(height: 1, color: p.line),
          const SizedBox(height: 12),
          Row(
            children: [
              if (running)
                const PulseDot()
              else
                Icon(Icons.timer_outlined, size: 22, color: p.textFaint),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, if (current != null) current],
                    ),
                    child: running && task.startedAt != null
                        ? ElapsedText(
                            key: const ValueKey('running'),
                            since: task.startedAt!,
                          )
                        : Text(
                            '00:00:00',
                            key: const ValueKey('idle'),
                            style: T.mono(
                              context,
                              size: 22,
                              color: p.textFaint,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (canAct)
                PrimaryButton(
                  label: running ? 'End task' : 'Start',
                  icon: running
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  compact: true,
                  expand: false,
                  busy: _busy,
                  onPressed: running ? _end : _start,
                )
              else
                GhostButton(
                  label: running ? 'End task' : 'Start',
                  icon: Icons.lock_outline_rounded,
                  compact: true,
                  expand: false,
                  onPressed: () => _locked(running ? 'end' : 'start'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
