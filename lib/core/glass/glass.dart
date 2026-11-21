import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import '../theme/palette.dart';

/// Liquid glass panel for the app chrome (bars, sheets, dialogs, toasts).
/// Strength follows Settings > Appearance. At 0, or when the phone asks for
/// high contrast, it becomes a solid panel with no blur.
class GlassSurface extends ConsumerWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 26,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final bool shadow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingsProvider.select((s) => s.glass));
    final p = context.palette;
    final br = borderRadius ?? BorderRadius.circular(radius);
    final solid = setting < 0.02 || MediaQuery.highContrastOf(context);
    final g = solid ? 0.0 : setting;

    final Widget painted = CustomPaint(
      painter: _GlassPainter(palette: p, g: g, radius: br),
      child: Padding(padding: padding, child: child),
    );

    final Widget clipped = ClipRRect(
      borderRadius: br,
      child: solid
          ? painted
          : BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 8 + 20 * g,
                sigmaY: 8 + 20 * g,
              ),
              child: painted,
            ),
    );

    if (!shadow) return clipped;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.30 : 0.10),
            blurRadius: 30,
            spreadRadius: -8,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: clipped,
    );
  }
}

class _GlassPainter extends CustomPainter {
  _GlassPainter({required this.palette, required this.g, required this.radius});

  final AltairPalette palette;
  final double g;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect);
    final dark = palette.isDark;

    final fillAlpha = g == 0 ? 1.0 : lerpDouble(0.86, 0.40, g)!;
    canvas.drawRRect(
      rrect,
      Paint()..color = palette.surface.withValues(alpha: fillAlpha),
    );

    if (g > 0) {
      final sheen = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: (dark ? 0.12 : 0.55) * g),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: (dark ? 0.04 : 0.20) * g),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect);
      canvas.drawRRect(rrect, sheen);
    }

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    if (g == 0) {
      rim.color = palette.line;
    } else {
      rim.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: (dark ? 0.16 : 0.75) + 0.30 * g),
          Colors.white.withValues(alpha: dark ? 0.05 : 0.30),
          palette.accent.withValues(alpha: 0.16 * g),
          (dark ? Colors.white : palette.text).withValues(
            alpha: 0.08 + 0.10 * g,
          ),
        ],
        stops: const [0, 0.42, 0.78, 1],
      ).createShader(rect);
    }
    canvas.drawRRect(rrect.deflate(0.55), rim);
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.g != g || old.palette != palette || old.radius != radius;
}

/// Card for list content. It only looks frosted - there is no live blur,
/// so long lists stay smooth and glass is never stacked on glass.
class FrostCard extends StatelessWidget {
  const FrostCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            p.surfaceHigh.withValues(alpha: p.isDark ? 0.92 : 1),
            p.surface.withValues(alpha: p.isDark ? 0.88 : 1),
          ],
        ),
        border: Border.all(
          color: highlight ? p.accent.withValues(alpha: 0.65) : p.line,
          width: highlight ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? p.accent.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: p.isDark ? 0.20 : 0.06),
            blurRadius: highlight ? 22 : 16,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Page background: the logo teal with two soft glows and a faint
/// engineering grid, so the glass panels have something to refract.
class AmbientBackground extends ConsumerWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(settingsProvider.select((s) => s.glass));
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _AmbientPainter(palette: context.palette, g: g),
          ),
        ),
        Image.asset(
          'assets/branding/background.png',
          fit: BoxFit.cover,
        ),
        ColoredBox(color: context.palette.bg.withValues(alpha: 0.72)),
        child,
      ],
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.palette, required this.g});

  final AltairPalette palette;
  final double g;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.bg, palette.bgDeep],
        ).createShader(rect),
    );

    void glow(Offset center, double r, Color color) {
      final area = Rect.fromCircle(center: center, radius: r);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(area),
      );
    }

    final dark = palette.isDark;
    glow(
      Offset(size.width * 0.92, size.height * 0.10),
      size.shortestSide * 0.85,
      palette.accent.withValues(alpha: (dark ? 0.05 : 0.06) + 0.09 * g),
    );
    glow(
      Offset(size.width * 0.05, size.height * 0.62),
      size.shortestSide * 0.95,
      (dark ? palette.surfaceHigh : Colors.white).withValues(
        alpha: 0.35 + 0.35 * g,
      ),
    );

    final grid = Paint()
      ..color = palette.text.withValues(alpha: dark ? 0.028 : 0.035)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // A shade that deepens toward the bottom, so the floating navigation
    // and the last cards always sit on a calm base.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.52, 1],
          colors: [
            palette.bgDeep.withValues(alpha: 0),
            palette.bgDeep.withValues(alpha: dark ? 0.88 : 0.55),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AmbientPainter old) =>
      old.g != g || old.palette != palette;
}
