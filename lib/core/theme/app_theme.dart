import 'package:flutter/material.dart';

import 'palette.dart';

ThemeData buildAltairTheme(AltairPalette p) {
  final scheme = ColorScheme(
    brightness: p.brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: p.ember,
    onError: p.onAccent,
    surface: p.surface,
    onSurface: p.text,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
    fontFamily: 'Quicksand',
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.line,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: <ThemeExtension<dynamic>>[p],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: p.text,
      displayColor: p.text,
      fontFamily: 'Quicksand',
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.3),
      selectionHandleColor: p.accent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.line,
      thumbColor: p.accent,
      overlayColor: p.accent.withValues(alpha: 0.14),
      trackHeight: 4,
    ),
  );
}

/// Text styles. Quicksand matches the logo wordmark; JetBrains Mono is used
/// for timers and IDs so digits do not jump while a clock is ticking.
abstract final class T {
  static TextStyle display(BuildContext c) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w700,
    fontSize: 27,
    height: 1.12,
    letterSpacing: 2.6,
    color: c.palette.text,
  );

  /// The giant condensed dashboard title (Bebas Neue, capitals only).
  static TextStyle giant(BuildContext c, double size) => TextStyle(
    fontFamily: 'BebasNeue',
    fontSize: size,
    height: 0.92,
    letterSpacing: 0.6,
    color: c.palette.text,
  );

  static TextStyle title(BuildContext c) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w700,
    fontSize: 17.5,
    height: 1.25,
    letterSpacing: 0.2,
    color: c.palette.text,
  );

  static TextStyle body(BuildContext c) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w500,
    fontSize: 14.5,
    height: 1.45,
    color: c.palette.textMuted,
  );

  static TextStyle strong(BuildContext c) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w700,
    fontSize: 14.5,
    height: 1.35,
    color: c.palette.text,
  );

  static TextStyle small(BuildContext c) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
    height: 1.35,
    color: c.palette.textFaint,
  );

  static TextStyle label(BuildContext c) => TextStyle(
    fontFamily: 'Quicksand',
    fontWeight: FontWeight.w700,
    fontSize: 11,
    height: 1.2,
    letterSpacing: 1.7,
    color: c.palette.textFaint,
  );

  static TextStyle mono(BuildContext c, {double size = 14, Color? color}) =>
      TextStyle(
        fontFamily: 'JetBrainsMono',
        fontWeight: FontWeight.w500,
        fontSize: size,
        height: 1.2,
        letterSpacing: 0.4,
        color: color ?? c.palette.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
