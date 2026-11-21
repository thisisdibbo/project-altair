import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';

const _suggestedCategories = ['Announcement', 'Technical', 'Logistics'];

Future<void> showNoteEditor(BuildContext context, {Note? existing}) =>
    showAltairSheet<void>(
      context,
      builder: (_) => _NoteEditor(existing: existing),
    );

class _NoteEditor extends ConsumerStatefulWidget {
  const _NoteEditor({required this.existing});

  final Note? existing;

  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _content = TextEditingController(text: widget.existing?.content);
  late final _category = TextEditingController(
    text: widget.existing?.category,
  );
  late final String _id =
      widget.existing?.id ?? ref.read(noteRepositoryProvider).newId();
  late bool _pinned = widget.existing?.pinned ?? false;
  late bool _important = widget.existing?.important ?? false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    setState(() => _busy = true);
    final repo = ref.read(noteRepositoryProvider);
    try {
      final bool synced;
      if (widget.existing == null) {
        synced = await repo.create(
          _id,
          title: _title.text.trim(),
          content: _content.text.trim(),
          category: _category.text.trim(),
          pinned: _pinned,
          important: _important,
          author: me,
        );
      } else {
        synced = await repo.update(
          _id,
          title: _title.text.trim(),
          content: _content.text.trim(),
          category: _category.text.trim(),
          pinned: _pinned,
          important: _important,
        );
      }
      if (!mounted) return;
      showToast(
        context,
        synced
            ? (widget.existing == null ? 'Note published' : 'Note updated')
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
    final perms = ref.watch(permissionsProvider);
    final me = perms?.user;
    final existing = widget.existing;
    final known = {
      ..._suggestedCategories,
      for (final n in ref.watch(notesProvider).value ?? const <Note>[])
        if (n.category.isNotEmpty) n.category,
    };
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(
            existing == null ? 'Create note' : 'Edit note',
            subtitle: 'Visible to every team member.',
          ),
          AltairTextField(
            controller: _title,
            label: 'Note title',
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Give the note a title' : null,
          ),
          const SizedBox(height: 16),
          AltairTextField(
            controller: _content,
            label: 'Note content',
            maxLines: 9,
            minLines: 5,
            maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Write the note' : null,
          ),
          const SizedBox(height: 16),
          const FieldLabel('Author'),
          Row(
            children: [
              Avatar(
                name: existing?.authorName ?? me?.fullName ?? '',
                url: existing?.authorPhotoUrl ?? me?.photoUrl,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  existing?.authorName ?? me?.fullName ?? '',
                  style: T.strong(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AltairTextField(
            controller: _category,
            label: 'Category (optional)',
            hint: 'e.g. Announcement',
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in known)
                FilterPill(
                  label: c,
                  selected: _category.text.trim() == c,
                  onTap: () => setState(() => _category.text = c),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SettingRow(
            icon: Icons.priority_high_rounded,
            title: 'Important',
            subtitle: 'Highlights the note in orange and notifies the team',
            trailing: AltairSwitch(
              value: _important,
              onChanged: (v) => setState(() => _important = v),
            ),
          ),
          if (perms?.pinNotes ?? false)
            SettingRow(
              icon: Icons.push_pin_outlined,
              title: 'Pinned',
              subtitle: 'Keeps the note at the top of the board',
              trailing: AltairSwitch(
                value: _pinned,
                onChanged: (v) => setState(() => _pinned = v),
              ),
            ),
          SheetActions(
            confirmLabel: existing == null ? 'Publish' : 'Save',
            busy: _busy,
            onConfirm: _save,
          ),
        ],
      ),
    );
  }
}
