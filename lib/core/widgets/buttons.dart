import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/palette.dart';

/// Press feedback used by every tappable element: a quick scale-down,
/// a soft dim and a light haptic tick.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (widget.onTap == null || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: enabled
            ? () {
                if (widget.haptic) Haptics.light();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _down ? 0.86 : 1,
            duration: const Duration(milliseconds: 130),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    this.compact = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expand;
  final bool compact;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = danger ? p.ember : p.accent;
    final fg = danger && !p.isDark ? Colors.white : p.onAccent;
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: PressScale(
        onTap: busy ? null : onPressed,
        child: Container(
          height: compact ? 42 : 52,
          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 14 : 17),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(base, Colors.white, 0.20)!, base],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: base.withValues(alpha: 0.32),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                )
              else ...[
                if (icon != null) ...[
                  Icon(icon, size: 19, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 12.5 : 13.5,
                      letterSpacing: 1.3,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.danger = false,
    this.accent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool compact;
  final bool danger;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = danger
        ? p.ember
        : accent
        ? p.accentText
        : p.text;
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: PressScale(
        onTap: onPressed,
        child: Container(
          height: compact ? 42 : 52,
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 14 : 17),
            color: p.surfaceHigh.withValues(alpha: p.isDark ? 0.45 : 0.9),
            border: Border.all(
              color: danger || accent ? fg.withValues(alpha: 0.5) : p.line,
            ),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : 13,
                    letterSpacing: 1.2,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      onTap: onTap,
      scale: 0.9,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.surfaceHigh.withValues(alpha: p.isDark ? 0.55 : 0.95),
          border: Border.all(color: p.line),
        ),
        child: Icon(icon, size: size * 0.48, color: color ?? p.text),
      ),
    );
  }
}

/// Floating orange PLUS button with a glossy highlight and a pop-in entrance.
class AltairFab extends StatelessWidget {
  const AltairFab({
    super.key,
    required this.onTap,
    this.icon = Icons.add_rounded,
    this.tooltip = 'Add',
  });

  final VoidCallback onTap;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: PressScale(
        onTap: onTap,
        scale: 0.9,
        semanticLabel: tooltip,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.45, -0.55),
              radius: 1.1,
              colors: [
                Color.lerp(p.accent, Colors.white, 0.38)!,
                p.accent,
                Color.lerp(p.accent, Colors.black, 0.12)!,
              ],
              stops: const [0, 0.55, 1],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: p.accent.withValues(alpha: 0.45),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, size: 30, color: p.onAccent),
        ),
      ),
    );
  }
}
