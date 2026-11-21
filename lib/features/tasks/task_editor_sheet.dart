import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';

/// Add Task / Edit Task panel. With [history] it edits a completed record
/// (administrators only); the recorded start and end times never change.
Future<void> showTaskEditor(
  BuildContext context, {
  RoverTask? existing,
  bool history = false,
}) => showAltairSheet<void>(
  context,
  builder: (_) => _TaskEditor(existing: existing, history: history),
);

class _TaskEditor extends ConsumerStatefulWidget {
  const _TaskEditor({required this.existing, required this.history});

  final RoverTask? existing;
  final bool history;

  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(
    text: widget.existing?.description,
  );
  late final String _id =
      widget.existing?.id ?? ref.read(taskRepositoryProvider).newId();

  late String _responsibleId = widget.existing?.responsibleId ?? '';
  late String _responsibleName = widget.existing?.responsibleName ?? '';
  late String _subTeamId = widget.existing?.subTeamId ?? '';
  late String _subTeamName = widget.existing?.subTeamName ?? '';
  late DateTime _when = widget.existing?.scheduledAt ?? DateTime.now();
  late String _priority = widget.existing?.priority ?? '';
  late DateTime? _due = widget.existing?.dueAt;
  bool _busy = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing == null) {
      final me = ref.read(currentUserProvider).value;
      if (me != null) {
        _responsibleId = me.id;
        _responsibleName = me.fullName;
        _subTeamId = me.subTeamId;
        _subTeamName = me.subTeamName;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickResponsible() async {
    final users = (ref.read(usersProvider).value ?? const <AppUser>[])
        .where((u) => !u.disabled)
        .toList();
    final picked = await showOptionsSheet<AppUser>(
      context,
      title: 'Responsible member',
      options: [
        for (final u in users)
          Option(
            u,
            u.fullName,
            subtitle: [
              u.role.label,
              if (u.subTeamName.isNotEmpty) u.subTeamName,
            ].join(' · '),
          ),
      ],
    );
    if (picked == null) return;
    setState(() {
      _responsibleId = picked.id;
      _responsibleName = picked.fullName;
      if (picked.subTeamId.isNotEmpty) {
        _subTeamId = picked.subTeamId;
        _subTeamName = picked.subTeamName;
      }
    });
  }

  Future<void> _pickSubTeam() async {
    final teams = ref.read(subTeamsProvider).value ?? const <SubTeam>[];
    final picked = await showOptionsSheet<SubTeam>(
      context,
      title: 'Sub-team',
      options: [for (final t in teams) Option(t, t.name)],
    );
    if (picked == null) return;
    setState(() {
      _subTeamId = picked.id;
      _subTeamName = picked.name;
    });
  }

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1100)),
    );
    if (date == null || !mounted) return;
    setState(() => _due = DateTime(date.year, date.month, date.day, 23, 59));
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _responsibleId.isEmpty || _subTeamId.isEmpty) return;
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;

    setState(() => _busy = true);
    final draft = TaskDraft(
      title: _title.text.trim(),
      description: _description.text.trim(),
      responsibleId: _responsibleId,
      responsibleName: _responsibleName,
      subTeamId: _subTeamId,
      subTeamName: _subTeamName,
      scheduledAt: _when,
      priority: _priority,
      dueAt: _due,
    );
    final repo = ref.read(taskRepositoryProvider);
    try {
      final bool synced;
      if (widget.existing == null) {
        synced = await repo.create(_id, draft, me);
      } else if (widget.history) {
        synced = await repo.updateHistory(_id, draft);
      } else {
        synced = await repo.update(_id, draft);
      }
      if (!mounted) return;
      showToast(
        context,
        synced
            ? (widget.existing == null ? 'Task added' : 'Task updated')
            : 'Saved on this phone. It will sync when you are online.',
        icon: synced
            ? Icons.check_circle_outline_rounded
            : Icons.cloud_queue_rounded,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final noTeams = (ref.watch(subTeamsProvider).value ?? const []).isEmpty;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(
            editing ? 'Edit task' : 'Add task',
            subtitle: widget.history
                ? 'Recorded start and end times cannot be changed.'
                : 'It appears on the live board for everyone.',
          ),
          AltairTextField(
            controller: _title,
            label: 'Task title',
            hint: 'e.g. Calibrate arm joint 3',
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Give the task a title' : null,
          ),
          const SizedBox(height: 16),
          AltairTextField(
            controller: _description,
            label: 'Task description',
            hint: 'What needs to be done?',
            maxLines: 5,
            minLines: 3,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          PickerField(
            label: 'Responsible member',
            icon: Icons.person_outline_rounded,
            value: _responsibleName,
            placeholder: 'Choose a member',
            errorText: _showErrors && _responsibleId.isEmpty
                ? 'Choose who is responsible'
                : null,
            onTap: _pickResponsible,
          ),
          const SizedBox(height: 16),
          PickerField(
            label: 'Sub-team',
            icon: Icons.hub_outlined,
            value: _subTeamName,
            placeholder: noTeams
                ? 'No sub-teams yet - ask an administrator'
                : 'Choose a sub-team',
            errorText: _showErrors && _subTeamId.isEmpty
                ? 'Choose a sub-team'
                : null,
            onTap: _pickSubTeam,
          ),
          const SizedBox(height: 16),
          PickerField(
            label: 'Scheduled / start time',
            icon: Icons.event_outlined,
            value: formatDateTime(_when),
            onTap: _pickWhen,
          ),
          const SizedBox(height: 16),
          PickerField(
            label: 'Deadline (optional)',
            icon: Icons.flag_outlined,
            value: _due == null ? null : formatDate(_due!),
            placeholder: 'No deadline',
            onTap: _pickDue,
            onClear: () => setState(() => _due = null),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Priority (optional)'),
          Segmented<String>(
            options: taskPriorities,
            selected: _priority,
            onChanged: (v) => setState(() => _priority = v),
          ),
          SheetActions(
            confirmLabel: editing ? 'Save' : 'Add task',
            busy: _busy,
            onConfirm: _save,
          ),
        ],
      ),
    );
  }
}
