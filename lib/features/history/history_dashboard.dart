import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/dashboard_scaffold.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_editor_sheet.dart';
import '../tasks/task_widgets.dart';

/// Every completed task, with search, filters and full details.
class HistoryDashboard extends ConsumerStatefulWidget {
  const HistoryDashboard({super.key});

  @override
  ConsumerState<HistoryDashboard> createState() => _HistoryDashboardState();
}

class _HistoryDashboardState extends ConsumerState<HistoryDashboard> {
  final _search = TextEditingController();
  String _query = '';
  IdName? _subTeam;
  IdName? _member;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(RoverTask t) {
    if (_subTeam != null && t.subTeamId != _subTeam!.id) return false;
    if (_member != null && t.responsibleId != _member!.id) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return t.title.toLowerCase().contains(q) ||
        t.description.toLowerCase().contains(q) ||
        t.responsibleName.toLowerCase().contains(q) ||
        t.subTeamName.toLowerCase().contains(q);
  }

  Future<void> _pickDates() async {
    final query = ref.read(historyQueryProvider);
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: query.from == null || query.to == null
          ? null
          : DateTimeRange(
              start: query.from!,
              end: query.to!.subtract(const Duration(days: 1)),
            ),
      helpText: 'Completed between',
    );
    if (range == null) return;
    ref
        .read(historyQueryProvider.notifier)
        .apply(
          query.withRange(
            DateTime(range.start.year, range.start.month, range.start.day),
            DateTime(
              range.end.year,
              range.end.month,
              range.end.day,
            ).add(const Duration(days: 1)),
          ),
        );
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
      title: 'Filter by member',
      allLabel: 'Everyone',
      selectedId: _member?.id,
      items: [for (final u in users) IdName(u.id, u.fullName)],
    );
    if (picked == null || !mounted) return;
    setState(() => _member = picked.id.isEmpty ? null : picked);
  }

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _subTeam = null;
      _member = null;
    });
    final query = ref.read(historyQueryProvider);
    ref.read(historyQueryProvider.notifier).apply(query.withRange(null, null));
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(historyQueryProvider);
    final history = ref.watch(historyProvider);
    final loaded = history.value ?? const <RoverTask>[];
    final items = loaded.where(_matches).toList();
    final dated = query.from != null && query.to != null;
    final filtered =
        dated || _subTeam != null || _member != null || _query.isNotEmpty;

    final Widget list;
    if (history.value == null && history.isLoading) {
      list = const SliverToBoxAdapter(child: SkeletonList(height: 96));
    } else if (history.value == null && history.hasError) {
      list = SliverToBoxAdapter(
        child: ErrorState(
          message: friendlyError(history.error!),
          onRetry: () => ref.invalidate(historyProvider),
        ),
      );
    } else if (items.isEmpty) {
      list = SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.history_rounded,
          title: filtered ? 'No matching records' : 'No history yet',
          message: filtered
              ? 'Try a different search or clear the filters.'
              : 'Tasks appear here automatically when they are ended.',
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

    return DashboardScaffold(
      index: 1,
      title: 'TASK\nHISTORY',
      facts: history.value == null
          ? const []
          : [
              (
                filtered
                    ? '${items.length}/${loaded.length}'
                    : '${loaded.length}',
                'Records',
              ),
              (
                formatDuration(
                  items.fold<Duration>(
                    Duration.zero,
                    (sum, t) => sum + (t.totalDuration ?? Duration.zero),
                  ),
                ),
                'Logged time',
              ),
            ],
      onRefresh: () async => ref.invalidate(historyProvider),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchField(
                controller: _search,
                hint: 'Search tasks, members, sub-teams',
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              PillRow(
                children: [
                  FilterPill(
                    label: dated
                        ? '${formatDate(query.from!)} - '
                              '${formatDate(query.to!.subtract(const Duration(days: 1)))}'
                        : 'Date',
                    icon: Icons.event_outlined,
                    selected: dated,
                    onTap: _pickDates,
                  ),
                  FilterPill(
                    label: _subTeam?.name ?? 'Sub-team',
                    icon: Icons.hub_outlined,
                    selected: _subTeam != null,
                    onTap: _pickSubTeam,
                  ),
                  FilterPill(
                    label: _member?.name ?? 'Member',
                    icon: Icons.person_outline_rounded,
                    selected: _member != null,
                    onTap: _pickMember,
                  ),
                  FilterPill(
                    label: query.newestFirst ? 'Newest first' : 'Oldest first',
                    icon: Icons.swap_vert_rounded,
                    selected: !query.newestFirst,
                    onTap: () => ref
                        .read(historyQueryProvider.notifier)
                        .apply(query.copyWith(newestFirst: !query.newestFirst)),
                  ),
                  if (filtered)
                    FilterPill(
                      label: 'Clear',
                      icon: Icons.close_rounded,
                      selected: false,
                      onTap: _clear,
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        list,
        if (loaded.length >= query.limit)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: GhostButton(
                  label: 'Load older records',
                  icon: Icons.expand_more_rounded,
                  expand: false,
                  compact: true,
                  onPressed: () => ref
                      .read(historyQueryProvider.notifier)
                      .apply(
                        query.copyWith(
                          limit: query.limit + HistoryQuery.pageSize,
                        ),
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.task});

  final RoverTask task;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final duration = task.totalDuration;
    return PressScale(
      scale: 0.985,
      onTap: () => showHistoryDetail(context, task),
      child: FrostCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: T.title(context).copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      MetaLine(
                        Icons.person_outline_rounded,
                        [
                          task.responsibleName,
                          task.subTeamName,
                        ].where((s) => s.isNotEmpty).join(' · '),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      duration == null ? '-' : formatDuration(duration),
                      style: T.mono(context, size: 16, color: p.accentText),
                    ),
                    const SizedBox(height: 6),
                    const StatusChip(status: TaskStatus.completed),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            MetaLine(
              Icons.schedule_rounded,
              '${formatDateTime(task.startedAt)}  →  '
              '${formatDateTime(task.endedAt)}',
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showHistoryDetail(BuildContext context, RoverTask task) async {
  final action = await showAltairSheet<String>(
    context,
    builder: (_) => _HistoryDetail(task: task),
  );
  if (action == 'edit' && context.mounted) {
    await showTaskEditor(context, existing: task, history: true);
  }
  if (action == 'details' && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(task: task)),
    );
  }
}

class _HistoryDetail extends ConsumerWidget {
  const _HistoryDetail({required this.task});

  final RoverTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(permissionsProvider)?.editHistory ?? false;
    final duration = task.totalDuration;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetTitle(task.title, subtitle: 'Completed task record'),
        Row(
          children: [
            const StatusChip(status: TaskStatus.completed),
            if (task.priority.isNotEmpty) ...[
              const SizedBox(width: 8),
              Tag(priorityLabel(task.priority), icon: Icons.flag_outlined),
            ],
          ],
        ),
        const SizedBox(height: 18),
        DetailRow('Responsible', task.responsibleName),
        DetailRow('Sub-team', task.subTeamName),
        DetailRow('Started', formatDateTime(task.startedAt), mono: true),
        DetailRow('Ended', formatDateTime(task.endedAt), mono: true),
        DetailRow(
          'Duration',
          duration == null ? '-' : formatDuration(duration),
          mono: true,
        ),
        DetailRow('Started by', task.startedByName),
        DetailRow('Ended by', task.endedByName),
        DetailRow('Created by', task.createdByName),
        DetailRow('Description', task.description),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: GhostButton(
            label: task.checklist.isEmpty
                ? 'Checklist & comments'
                : 'Checklist '
                      '${task.checklist.where((c) => c.done).length}/'
                      '${task.checklist.length} · comments',
            icon: Icons.checklist_rounded,
            compact: true,
            onPressed: () => Navigator.of(context).pop('details'),
          ),
        ),
        if (canEdit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    compact: true,
                    onPressed: () => Navigator.of(context).pop('edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GhostButton(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    compact: true,
                    danger: true,
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Delete this record?',
                        message:
                            '"${task.title}" will be permanently removed '
                            'from History for everyone.',
                        confirmLabel: 'Delete',
                        danger: true,
                      );
                      if (!ok || !context.mounted) return;
                      try {
                        await ref
                            .read(taskRepositoryProvider)
                            .deleteHistory(task.id, label: task.title);
                        if (!context.mounted) return;
                        showToast(context, 'Record deleted');
                        Navigator.of(context).pop();
                      } catch (e) {
                        if (context.mounted) {
                          showToast(context, friendlyError(e), error: true);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
