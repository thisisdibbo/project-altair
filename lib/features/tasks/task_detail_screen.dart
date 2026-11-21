import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/sub_page.dart';
import 'task_widgets.dart';

/// One task in full: its description, its checklist and its comments.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.task});

  /// The task as it was when the page was opened. While it is still on the
  /// live board the page follows the live copy instead.
  final RoverTask task;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _item = TextEditingController();
  final _comment = TextEditingController();
  bool _sending = false;

  String get _id => widget.task.id;

  @override
  void dispose() {
    _item.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _try(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _addItem() async {
    final text = _item.text.trim();
    if (text.isEmpty) return;
    _item.clear();
    await _try(
      () => ref.read(extrasRepositoryProvider).addChecklistItem(_id, text),
    );
  }

  Future<void> _sendComment() async {
    final text = _comment.text.trim();
    final me = ref.read(currentUserProvider).value;
    if (text.isEmpty || me == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(extrasRepositoryProvider).addComment(_id, text, me);
      _comment.clear();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final perms = ref.watch(permissionsProvider);
    final live = ref
        .watch(activeTasksProvider)
        .value
        ?.where((t) => t.id == _id)
        .firstOrNull;
    final task = live ?? widget.task;
    final canEdit = live != null && (perms?.canEnd(task) ?? false);
    final repo = ref.read(extrasRepositoryProvider);
    final comments = ref.watch(taskCommentsProvider(_id));
    final list = comments.value ?? const <TaskComment>[];
    final done = task.checklist.where((c) => c.done).length;

    return SubPage(
      title: 'TASK',
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FrostCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusChip(status: task.status),
                const SizedBox(height: 12),
                Text(task.title, style: T.title(context)),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SelectableText(task.description, style: T.body(context)),
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
                      task.subTeamName.isEmpty
                          ? 'No sub-team'
                          : task.subTeamName,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SectionCard(
          title: task.checklist.isEmpty
              ? 'Checklist'
              : 'Checklist · $done of ${task.checklist.length} done',
          children: [
            if (task.checklist.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  canEdit
                      ? 'Break the task into small steps and tick them off.'
                      : 'No steps have been added yet.',
                  style: T.small(context),
                ),
              ),
            for (final item in task.checklist)
              Padding(
                key: ValueKey(item.id),
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: item.done ? 'Mark as not done' : 'Mark as done',
                      onPressed: canEdit
                          ? () => _try(
                              () => repo.toggleChecklistItem(_id, item.id),
                            )
                          : null,
                      icon: Icon(
                        item.done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: item.done ? p.accentText : p.textFaint,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.text,
                        style: T.body(context).copyWith(
                          color: item.done ? p.textFaint : p.text,
                          decoration: item.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (canEdit)
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => _try(
                          () => repo.removeChecklistItem(_id, item.id),
                        ),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: p.textFaint,
                        ),
                      ),
                  ],
                ),
              ),
            if (canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AltairTextField(
                        controller: _item,
                        label: 'New step',
                        hint: 'e.g. Tighten the wheel hub bolts',
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _addItem(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PrimaryButton(
                      label: 'Add',
                      icon: Icons.add_rounded,
                      expand: false,
                      onPressed: _addItem,
                    ),
                  ],
                ),
              ),
          ],
        ),
        SectionCard(
          title: list.isEmpty ? 'Comments' : 'Comments · ${list.length}',
          children: [
            if (comments.value == null && comments.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Skeleton(height: 44, radius: 14),
              )
            else if (comments.value == null && comments.hasError)
              ErrorState(
                message: friendlyError(comments.error!),
                onRetry: () => ref.invalidate(taskCommentsProvider(_id)),
              )
            else if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('No comments yet.', style: T.small(context)),
              ),
            for (final c in list)
              Padding(
                key: ValueKey(c.id),
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.authorName} · ${formatFriendly(c.createdAt)}',
                            style: T.small(context),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(c.text, style: T.body(context)),
                        ],
                      ),
                    ),
                    if (perms != null &&
                        (perms.role.isLead || c.authorId == perms.user.id))
                      IconButton(
                        tooltip: 'Delete comment',
                        onPressed: () =>
                            _try(() => repo.deleteComment(_id, c.id)),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: p.textFaint,
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AltairTextField(
                      controller: _comment,
                      label: 'Add a comment',
                      hint: 'Write an update or a question',
                      maxLength: 1000,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 10),
                  PrimaryButton(
                    label: 'Send',
                    icon: Icons.send_rounded,
                    expand: false,
                    busy: _sending,
                    onPressed: _sendComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "CHECKLIST 2/5 · COMMENTS ›" under a task card; opens the task page.
class TaskDetailsLink extends StatelessWidget {
  const TaskDetailsLink({super.key, required this.task});

  final RoverTask task;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final steps = task.checklist;
    final done = steps.where((c) => c.done).length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(task: task)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Icon(Icons.checklist_rounded, size: 16, color: p.accentText),
            const SizedBox(width: 6),
            Text(
              steps.isEmpty
                  ? 'CHECKLIST & COMMENTS'
                  : 'CHECKLIST $done/${steps.length} · COMMENTS',
              style: T.label(context).copyWith(color: p.accentText),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: p.accentText),
          ],
        ),
      ),
    );
  }
}
