import 'package:flutter/material.dart';

import '../../core/core.dart';

/// "Due 20 Nov 2026" under a task. It turns red once the deadline has passed.
class DueLine extends StatelessWidget {
  const DueLine(this.due, {super.key});

  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final overdue = due.isBefore(DateTime.now());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          overdue ? Icons.warning_amber_rounded : Icons.flag_outlined,
          size: 15,
          color: overdue ? p.ember : p.textFaint,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            overdue
                ? 'Overdue · was due ${formatDate(due)}'
                : 'Due ${formatDate(due)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: T.small(context).copyWith(
              color: overdue ? p.ember : p.textMuted,
              fontWeight: overdue ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
  }
}
