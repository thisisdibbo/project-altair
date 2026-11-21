import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/sub_page.dart';
import '../tasks/task_widgets.dart';

/// Team votes. Any member can start a poll and vote; tapping another option
/// changes your vote until the poll is closed.
class PollsScreen extends ConsumerWidget {
  const PollsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pollsProvider);
    final all = state.value ?? const <Poll>[];
    return SubPage(
      title: 'POLLS',
      action: RoundIconButton(
        icon: Icons.add_rounded,
        tooltip: 'New poll',
        onTap: () => showPollEditor(context),
      ),
      children: [
        if (state.value == null && state.isLoading)
          const SkeletonList(height: 180, count: 3)
        else if (state.value == null && state.hasError)
          ErrorState(
            message: friendlyError(state.error!),
            onRetry: () => ref.invalidate(pollsProvider),
          )
        else if (all.isEmpty)
          const EmptyState(
            icon: Icons.how_to_vote_outlined,
            title: 'No polls yet',
            message: 'Tap + at the top to ask the team a question.',
          )
        else
          for (final poll in all)
            Padding(
              key: ValueKey(poll.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _PollCard(poll: poll),
            ),
      ],
    );
  }
}

class _PollCard extends ConsumerWidget {
  const _PollCard({required this.poll});

  final Poll poll;

  Future<void> _try(
    BuildContext context,
    Future<Object?> Function() action, [
    String? done,
  ]) async {
    try {
      await action();
      if (done != null && context.mounted) showToast(context, done);
    } catch (e) {
      if (context.mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _more(BuildContext context, WidgetRef ref) async {
    final action = await showOptionsSheet<String>(
      context,
      title: poll.question,
      options: [
        Option('close', poll.closed ? 'Reopen voting' : 'Close voting'),
        const Option('delete', 'Delete poll'),
      ],
    );
    if (action == null || !context.mounted) return;
    final repo = ref.read(extrasRepositoryProvider);
    if (action == 'close') {
      await _try(
        context,
        () => repo.setPollClosed(poll.id, !poll.closed),
        poll.closed ? 'Voting reopened' : 'Voting closed',
      );
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Delete this poll?',
      message: '"${poll.question}" and its votes will be removed.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    await _try(
      context,
      () => repo.deletePoll(poll.id, label: poll.question),
      'Poll deleted',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final perms = ref.watch(permissionsProvider);
    final myId = perms?.user.id;
    final mine = poll.choiceOf(myId);
    final canManage =
        perms != null && (perms.role.isLead || poll.createdById == myId);
    final total = poll.total;

    return FrostCard(
      highlight: !poll.closed && mine == null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tag(
                poll.closed ? 'Closed' : 'Open',
                icon: poll.closed
                    ? Icons.lock_outline_rounded
                    : Icons.how_to_vote_outlined,
                accent: !poll.closed,
              ),
              const Spacer(),
              if (canManage)
                RoundIconButton(
                  icon: Icons.more_horiz_rounded,
                  size: 34,
                  tooltip: 'Poll actions',
                  onTap: () => _more(context, ref),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(poll.question, style: T.title(context)),
          const SizedBox(height: 12),
          for (var i = 0; i < poll.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionBar(
                label: poll.options[i],
                count: poll.countFor(i),
                total: total,
                chosen: mine == i,
                onTap: poll.closed || myId == null || mine == i
                    ? null
                    : () => _try(
                        context,
                        () => ref
                            .read(extrasRepositoryProvider)
                            .vote(poll.id, myId, i),
                      ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            [
              '$total vote${total == 1 ? '' : 's'}',
              if (poll.createdByName.isNotEmpty) 'by ${poll.createdByName}',
              formatFriendly(poll.createdAt),
              if (!poll.closed && mine == null) 'tap an option to vote',
            ].join(' · '),
            style: T.small(context).copyWith(
              color: !poll.closed && mine == null ? p.accentText : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionBar extends StatelessWidget {
  const _OptionBar({
    required this.label,
    required this.count,
    required this.total,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final int count;
  final int total;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final share = total == 0 ? 0.0 : count / total;
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: p.surfaceHigh.withValues(alpha: p.isDark ? 0.55 : 0.9),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: share,
              child: ColoredBox(
                color: p.accent.withValues(alpha: chosen ? 0.38 : 0.16),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: chosen ? p.accent : p.line,
                width: chosen ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  chosen
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: chosen ? p.accentText : p.textFaint,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: T.strong(context))),
                const SizedBox(width: 10),
                Text(
                  '${(share * 100).round()}% · $count',
                  style: T.small(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return bar;
    return PressScale(scale: 0.985, onTap: onTap!, child: bar);
  }
}

/// The New poll form.
Future<void> showPollEditor(BuildContext context) =>
    showAltairSheet<void>(context, builder: (_) => const _PollEditor());

class _PollEditor extends ConsumerStatefulWidget {
  const _PollEditor();

  @override
  ConsumerState<_PollEditor> createState() => _PollEditorState();
}

class _PollEditorState extends ConsumerState<_PollEditor> {
  static const _maxOptions = 6;

  final _formKey = GlobalKey<FormState>();
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  bool _busy = false;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    final options = [
      for (final c in _options)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    setState(() => _busy = true);
    try {
      final synced = await ref
          .read(extrasRepositoryProvider)
          .addPoll(_question.text.trim(), options, me);
      if (!mounted) return;
      showToast(
        context,
        synced
            ? 'Poll started'
            : 'Saved on this phone. It will sync when you are online.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'New poll',
          subtitle: 'Everyone in the team can vote once.',
        ),
        AltairTextField(
          controller: _question,
          label: 'Question',
          hint: 'e.g. Which day suits the field test?',
          maxLength: 200,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Write the question' : null,
        ),
        for (var i = 0; i < _options.length; i++) ...[
          const SizedBox(height: 14),
          AltairTextField(
            controller: _options[i],
            label: 'Option ${i + 1}',
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: (v) => i < 2 && (v == null || v.trim().isEmpty)
                ? 'A poll needs at least two options'
                : null,
          ),
        ],
        if (_options.length < _maxOptions) ...[
          const SizedBox(height: 12),
          GhostButton(
            label: 'Add option',
            icon: Icons.add_rounded,
            compact: true,
            onPressed: () =>
                setState(() => _options.add(TextEditingController())),
          ),
        ],
        SheetActions(confirmLabel: 'Start poll', busy: _busy, onConfirm: _save),
      ],
    ),
  );
}
