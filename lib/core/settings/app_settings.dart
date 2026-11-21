import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../motion/motion.dart';

final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider is set in main()'),
);

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.glass = defaultGlass,
    this.rememberMe = true,
    this.reduceMotion = false,
    this.haptics = true,
    this.mutedAlerts = const {},
  });

  static const defaultGlass = 0.35;

  final ThemeMode themeMode;

  /// Liquid glass intensity, 0 (solid panels) to 1 (most translucent).
  final double glass;
  final bool rememberMe;

  /// Skips the cinematic reveals and the portal transition.
  final bool reduceMotion;
  final bool haptics;

  /// Keys of the live alerts this member switched off.
  final Set<String> mutedAlerts;

  bool alertOn(String key) => !mutedAlerts.contains(key);

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? glass,
    bool? rememberMe,
    bool? reduceMotion,
    bool? haptics,
    Set<String>? mutedAlerts,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    glass: glass ?? this.glass,
    rememberMe: rememberMe ?? this.rememberMe,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    haptics: haptics ?? this.haptics,
    mutedAlerts: mutedAlerts ?? this.mutedAlerts,
  );
}

/// Settings are stored on the phone (they are personal, not team data).
class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() {
    final p = ref.watch(sharedPrefsProvider);
    final settings = AppSettings(
      themeMode:
          ThemeMode.values.asNameMap()[p.getString('themeMode')] ??
          ThemeMode.dark,
      glass: (p.getDouble('glass') ?? AppSettings.defaultGlass)
          .clamp(0.0, 1.0)
          .toDouble(),
      rememberMe: p.getBool('rememberMe') ?? true,
      reduceMotion: p.getBool('reduceMotion') ?? false,
      haptics: p.getBool('haptics') ?? true,
      mutedAlerts: {...?p.getStringList('mutedAlerts')},
    );
    Motion.reduced = settings.reduceMotion;
    Haptics.enabled = settings.haptics;
    return settings;
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs.setString('themeMode', mode.name);
  }

  void setGlass(double value) {
    final v = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(glass: v);
    _prefs.setDouble('glass', v);
  }

  void setRememberMe(bool value) {
    state = state.copyWith(rememberMe: value);
    _prefs.setBool('rememberMe', value);
  }

  void setReduceMotion(bool value) {
    Motion.reduced = value;
    state = state.copyWith(reduceMotion: value);
    _prefs.setBool('reduceMotion', value);
  }

  void setHaptics(bool value) {
    Haptics.enabled = value;
    state = state.copyWith(haptics: value);
    _prefs.setBool('haptics', value);
    Haptics.select();
  }

  void setAlert(String key, bool on) {
    final muted = {...state.mutedAlerts};
    on ? muted.remove(key) : muted.add(key);
    state = state.copyWith(mutedAlerts: muted);
    _prefs.setStringList('mutedAlerts', muted.toList());
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
