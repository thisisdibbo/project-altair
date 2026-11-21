import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared easing and the "Reduce motion" switch.
/// The two curves are the ones the Planet Jumping reference uses everywhere.
abstract final class Motion {
  /// Settings > Appearance > Reduce motion.
  static bool reduced = false;

  /// cubic-bezier(.22, 1, .36, 1) - quick start, long soft landing.
  static const soft = Cubic(0.22, 1, 0.36, 1);

  /// cubic-bezier(.16, 1, .3, 1) - used for the big title and the logo glide.
  static const expo = Cubic(0.16, 1, 0.3, 1);

  static bool off(BuildContext context) =>
      reduced || MediaQuery.disableAnimationsOf(context);

  /// easeInOutCubic, used while the portal window expands.
  static double inOutCubic(double t) {
    if (t < 0.5) return 4 * t * t * t;
    final u = -2 * t + 2;
    return 1 - u * u * u / 2;
  }
}

/// Haptic ticks, switchable in Settings > General.
abstract final class Haptics {
  static bool enabled = true;

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}

/// Fades, un-blurs and slides its child into place.
/// It plays once when built and again every time [trigger] changes to a
/// value of zero or more (dashboards use this when they come into view).
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.trigger = 0,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 720),
    this.offset = const Offset(0, 18),
    this.blur = 7,
    this.curve = Motion.soft,
  });

  final Widget child;
  final int trigger;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double blur;
  final Curve curve;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(Reveal old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger >= 0) _play();
  }

  void _play() {
    if (Motion.reduced) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = (widget.delay + widget.duration).inMilliseconds;
    final start = total == 0 ? 0.0 : widget.delay.inMilliseconds / total;
    final curve = Interval(start, 1, curve: widget.curve);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final v = curve.transform(_c.value).clamp(0.0, 1.0).toDouble();
        if (v >= 1) return child!;
        Widget out = Opacity(
          opacity: v,
          child: Transform.translate(
            offset: widget.offset * (1 - v),
            child: child,
          ),
        );
        final sigma = widget.blur * (1 - v);
        if (sigma > 0.3) {
          out = ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: out,
          );
        }
        return out;
      },
    );
  }
}
