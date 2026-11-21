import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/sub_page.dart';
import '../tasks/task_widgets.dart';
import 'hub_widgets.dart';

IconData _typeIcon(String type) => switch (type) {
  'meeting' => Icons.groups_2_outlined,
  'test' => Icons.terrain_outlined,
  'deadline' => Icons.flag_outlined,
  _ => Icons.event_outlined,
};

/// Meetings, test days and deadlines, each with a countdown.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TeamEvent event,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete "${event.title}"?',
      message: 'It will be removed from the calendar for everyone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(hubRepositoryProvider)
          .deleteEvent(event.id, label: event.title);
      if (context.mounted) showToast(context, 'Event deleted');
    } catch (e) {
      if (context.mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manage = ref.watch(permissionsProvider)?.manageEvents ?? false;
    final state = ref.watch(eventsProvider);
    final all = state.value ?? const <TeamEvent>[];
    final now = DateTime.now();
    final upcoming = all.where((e) => e.daysFrom(now) >= 0).toList();
    final past = all.where((e) => e.daysFrom(now) < 0).toList().reversed;

    Widget card(TeamEvent e) => Padding(
      key: ValueKey(e.id),
      padding: const EdgeInsets.only(bottom: 12),
      child: _EventCard(
        event: e,
        days: e.daysFrom(now),
        onEdit: manage ? () => showEventEditor(context, existing: e) : null,
        onDelete: manage ? () => _delete(context, ref, e) : null,
      ),
    );

    return SubPage(
      title: 'CALENDAR',
      action: RoundIconButton(
        icon: Icons.add_rounded,
        tooltip: 'Add event',
        onTap: () => showEventEditor(context),
      ),
      children: [
        if (state.value == null && state.isLoading)
          const SkeletonList(height: 96, count: 4)
        else if (state.value == null && state.hasError)
          ErrorState(
            message: friendlyError(state.error!),
            onRetry: () => ref.invalidate(eventsProvider),
          )
        else if (all.isEmpty)
          EmptyState(
            icon: Icons.event_outlined,
            title: 'Nothing planned yet',
            message: 'Tap + at the top to add a meeting, test day or deadline.',
          )
        else ...[
          if (upcoming.isEmpty)
            const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'Nothing coming up',
              message: 'Events from the past month are listed below.',
            ),
          for (final e in upcoming) card(e),
          if (past.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
              child: Text('PAST MONTH', style: T.label(context)),
            ),
            for (final e in past) card(e),
          ],
        ],
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.days,
    required this.onEdit,
    required this.onDelete,
  });

  final TeamEvent event;
  final int days;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => FrostCard(
    highlight: days == 0,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Tag(eventTypeLabel(event.type), icon: _typeIcon(event.type)),
            const Spacer(),
            Tag(
              countdownLabel(days),
              icon: Icons.hourglass_bottom_rounded,
              accent: days >= 0 && days <= 3,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(event.title, style: T.title(context)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 7,
          children: [
            MetaLine(Icons.schedule_rounded, formatDateTime(event.at)),
            if (event.location.isNotEmpty)
              MetaLine(Icons.place_outlined, event.location),
          ],
        ),
        if (event.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(event.notes, style: T.small(context)),
        ],
        if (onEdit != null || onDelete != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  compact: true,
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  compact: true,
                  danger: true,
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// A slim card for the home screen: the next event and how far away it is.
/// It takes no space while nothing is planned.
class NextEventBanner extends ConsumerWidget {
  const NextEventBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextEventProvider);
    if (next == null) return const SizedBox.shrink();
    final p = context.palette;
    final days = next.daysFrom(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressScale(
        scale: 0.985,
        semanticLabel: 'Open the calendar',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CalendarScreen()),
        ),
        child: FrostCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          highlight: days <= 1,
          child: Row(
            children: [
              Icon(_typeIcon(next.type), size: 22, color: p.accentText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT · ${eventTypeLabel(next.type).toUpperCase()}',
                      style: T.label(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      next.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.strong(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                countdownLabel(days).toUpperCase(),
                style: T.title(context).copyWith(
                  color: p.accentText,
                  fontSize: 14,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add / edit a calendar entry.
Future<void> showEventEditor(BuildContext context, {TeamEvent? existing}) =>
    showAltairSheet<void>(
      context,
      builder: (_) => _EventEditor(existing: existing),
    );

class _EventEditor extends ConsumerStatefulWidget {
  const _EventEditor({required this.existing});

  final TeamEvent? existing;

  @override
  ConsumerState<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<_EventEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _location = TextEditingController(
    text: widget.existing?.location,
  );
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late String _type = widget.existing?.type ?? eventTypes.first.$1;
  late DateTime _at =
      widget.existing?.at ?? DateTime.now().add(const Duration(days: 1));
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1100)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time == null || !mounted) return;
    setState(() {
      _at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    setState(() => _busy = true);
    final draft = EventDraft(
      title: _title.text.trim(),
      type: _type,
      at: _at,
      location: _location.text.trim(),
      notes: _notes.text.trim(),
    );
    final repo = ref.read(hubRepositoryProvider);
    final existing = widget.existing;
    try {
      final synced = existing == null
          ? await repo.addEvent(draft, uid)
          : await repo.updateEvent(existing.id, draft);
      if (!mounted) return;
      showToast(
        context,
        synced
            ? (existing == null ? 'Event added' : 'Event updated')
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
        SheetTitle(
          widget.existing == null ? 'Add event' : 'Edit event',
          subtitle: 'Shown in the calendar for everyone.',
        ),
        AltairTextField(
          controller: _title,
          label: 'Title',
          hint: 'e.g. Full rover field test',
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Give the event a title' : null,
        ),
        const SizedBox(height: 16),
        const FieldLabel('Type'),
        Segmented<String>(
          options: eventTypes,
          selected: _type,
          onChanged: (v) => setState(() => _type = v),
        ),
        const SizedBox(height: 16),
        PickerField(
          label: 'Date and time',
          icon: Icons.event_outlined,
          value: formatDateTime(_at),
          onTap: _pickAt,
        ),
        const SizedBox(height: 16),
        AltairTextField(
          controller: _location,
          label: 'Place (optional)',
          hint: 'e.g. Robotics lab',
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        AltairTextField(
          controller: _notes,
          label: 'Notes (optional)',
          maxLines: 3,
          minLines: 2,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
        ),
        SheetActions(
          confirmLabel: widget.existing == null ? 'Add event' : 'Save',
          busy: _busy,
          onConfirm: _save,
        ),
      ],
    ),
  );
}
