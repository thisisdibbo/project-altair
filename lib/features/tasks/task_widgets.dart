import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';

/// Live elapsed time. It is recomputed every second from the server start
/// time, so it stays correct after the app is closed, the phone restarts
/// or another member opens the board.
class ElapsedText extends ConsumerStatefulWidget {
  const ElapsedText({super.key, required this.since, this.size = 22});

  final DateTime since;
  final double size;

  @override
  ConsumerState<ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends ConsumerState<ElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(serverClockProvider).now();
    return Text(
      formatElapsed(now.difference(widget.since)),
      style: T.mono(
        context,
        size: widget.size,
        color: context.palette.accentText,
      ),
    );
  }
}

/// Orange dot with a soft expanding ring, shown on running tasks.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.size = 10});

  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.off(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s * (1 + 1.4 * _c.value),
              height: s * (1 + 1.4 * _c.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.35 * (1 - _c.value)),
              ),
            ),
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = switch (status) {
      TaskStatus.pending => p.textMuted,
      TaskStatus.inProgress => p.accentText,
      TaskStatus.completed => p.calm,
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(status),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withValues(alpha: 0.13),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (status) {
                TaskStatus.pending => Icons.hourglass_empty_rounded,
                TaskStatus.inProgress => Icons.bolt_rounded,
                TaskStatus.completed => Icons.check_rounded,
              },
              size: 13,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              status.label,
              style: T.label(context).copyWith(color: color, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.icon, this.accent = false});

  final String text;
  final IconData? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = accent ? p.accentText : p.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent
            ? p.accent.withValues(alpha: 0.14)
            : p.text.withValues(alpha: 0.06),
        border: Border.all(
          color: accent ? p.accent.withValues(alpha: 0.5) : p.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.label(context).copyWith(color: color, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class MetaLine extends StatelessWidget {
  const MetaLine(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: context.palette.textFaint),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: T.small(context).copyWith(color: context.palette.textMuted),
        ),
      ),
    ],
  );
}

String priorityLabel(String key) => taskPriorities
    .firstWhere((p) => p.$1 == key, orElse: () => taskPriorities.first)
    .$2;

/// Label + value row used in detail sheets.
class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(label.toUpperCase(), style: T.label(context)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: mono
                ? T.mono(context, size: 13.5)
                : T.strong(context).copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
