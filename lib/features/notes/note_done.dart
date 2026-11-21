import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';

/// The row under a note with its Done button. Once a note is ticked off it
/// shows who did it, and can be reopened.
class NoteDoneRow extends ConsumerWidget {
  const NoteDoneRow({super.key, required this.note});

  final Note note;

  Future<void> _set(BuildContext context, WidgetRef ref, bool done) async {
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    try {
      await ref
          .read(noteRepositoryProvider)
          .setDone(note.id, done, me, label: note.title);
      if (context.mounted) {
        showToast(context, done ? 'Marked as done' : 'Note reopened');
      }
    } catch (e) {
      if (context.mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    if (!note.done) {
      return Align(
        alignment: Alignment.centerRight,
        child: GhostButton(
          label: 'Done',
          icon: Icons.check_rounded,
          expand: false,
          compact: true,
          accent: true,
          onPressed: () => _set(context, ref, true),
        ),
      );
    }
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, size: 18, color: p.accentText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            note.doneByName.isEmpty ? 'Done' : 'Done · ${note.doneByName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: T.small(context).copyWith(color: p.accentText),
          ),
        ),
        GhostButton(
          label: 'Reopen',
          expand: false,
          compact: true,
          onPressed: () => _set(context, ref, false),
        ),
      ],
    );
  }
}
