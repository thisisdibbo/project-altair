import 'package:flutter/material.dart';

/// Colours sampled from the official Project Altair logo.
/// Everything in the app reads its colours from here.
@immutable
class AltairPalette extends ThemeExtension<AltairPalette> {
  const AltairPalette({
    required this.brightness,
    required this.bg,
    required this.bgDeep,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.accentText,
    required this.onAccent,
    required this.calm,
    required this.ember,
  });

  final Brightness brightness;
  final Color bg;
  final Color bgDeep;
  final Color surface;
  final Color surfaceHigh;
  final Color line;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color accent;
  final Color accentText;
  final Color onAccent;
  final Color calm;
  final Color ember;

  bool get isDark => brightness == Brightness.dark;

  static const logoTeal = Color(0xFF0B1E24);
  static const logoOrange = Color(0xFFF5841C);

  static const dark = AltairPalette(
    brightness: Brightness.dark,
    bg: logoTeal,
    bgDeep: Color(0xFF061317),
    surface: Color(0xFF112A31),
    surfaceHigh: Color(0xFF18373F),
    line: Color(0x1FFFFFFF),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFFB9C7CA),
    textFaint: Color(0xFF7F959A),
    accent: logoOrange,
    accentText: logoOrange,
    onAccent: logoTeal,
    calm: Color(0xFF9CC3C9),
    ember: Color(0xFFFF7A3D),
  );

  static const light = AltairPalette(
    brightness: Brightness.light,
    bg: Color(0xFFEEF3F4),
    bgDeep: Color(0xFFDFE8EA),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF4F8F8),
    line: Color(0x1F0B1E24),
    text: logoTeal,
    textMuted: Color(0xFF43585D),
    textFaint: Color(0xFF75898E),
    accent: logoOrange,
    accentText: Color(0xFFB8560A),
    onAccent: logoTeal,
    calm: Color(0xFF2F5F68),
    ember: Color(0xFFC2410C),
  );

  @override
  AltairPalette copyWith() => this;

  @override
  AltairPalette lerp(ThemeExtension<AltairPalette>? other, double t) {
    if (other is! AltairPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AltairPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: c(bg, other.bg),
      bgDeep: c(bgDeep, other.bgDeep),
      surface: c(surface, other.surface),
      surfaceHigh: c(surfaceHigh, other.surfaceHigh),
      line: c(line, other.line),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      textFaint: c(textFaint, other.textFaint),
      accent: c(accent, other.accent),
      accentText: c(accentText, other.accentText),
      onAccent: c(onAccent, other.onAccent),
      calm: c(calm, other.calm),
      ember: c(ember, other.ember),
    );
  }
}

extension PaletteContext on BuildContext {
  AltairPalette get palette =>
      Theme.of(this).extension<AltairPalette>() ?? AltairPalette.dark;
}
