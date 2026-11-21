import 'package:flutter/material.dart';

import '../glass/glass.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'buttons.dart';

/// Shimmering placeholder shown while a list is loading.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 104, this.radius = 22});

  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = p.surface.withValues(alpha: p.isDark ? 0.8 : 1);
    final hi = p.surfaceHigh;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: p.line),
            gradient: LinearGradient(
              begin: Alignment(-1.6 + 3.2 * t, 0),
              end: Alignment(-0.6 + 3.2 * t, 0),
              colors: [base, hi, base],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.height = 104});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < count; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Skeleton(height: height),
        ),
    ],
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.accent.withValues(alpha: 0.10),
              border: Border.all(color: p.accent.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 32, color: p.accentText),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: T.title(context)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: T.body(context)),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load',
        message: message,
      ),
      if (onRetry != null)
        GhostButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          expand: false,
          compact: true,
          onPressed: onRetry,
        ),
    ],
  );
}

void showToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_outline_rounded,
  bool error = false,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      icon: error ? Icons.error_outline_rounded : icon,
      error: error,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.icon,
    required this.error,
    required this.onDone,
  });

  final String message;
  final IconData icon;
  final bool error;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _c.forward();
    await Future<void>.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    await _c.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.4),
              end: Offset.zero,
            ).animate(curved),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: GestureDetector(
                  onTap: () => _c.reverse().then((_) => widget.onDone()),
                  child: GlassSurface(
                    radius: 20,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon,
                          size: 20,
                          color: widget.error ? p.ember : p.accentText,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: T.strong(context).copyWith(fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, a1, a2) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            type: MaterialType.transparency,
            child: GlassSurface(
              radius: 28,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.title(dialogContext)),
                  const SizedBox(height: 10),
                  Text(message, style: T.body(dialogContext)),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: GhostButton(
                          label: cancelLabel,
                          compact: true,
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: confirmLabel,
                          compact: true,
                          danger: danger,
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, a2, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}
