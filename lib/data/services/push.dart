import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../app/config.dart';
import 'live_alerts.dart';
import 'nudge_io.dart' if (dart.library.js_interop) 'nudge_web.dart';

/// Notifications that arrive while the app is closed (Android only: an
/// iPhone needs a paid Apple developer account for them).
///
/// The phone listens on one topic per kind of alert that is switched on.
/// The sending is done by the team's free Google Apps Script
/// (tools/apps-script/Code.gs), which the app nudges after each change.
abstract final class Push {
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _queue = Future.value();
  static String? _applied;
  static bool _asked = false;

  /// Listens on exactly the [topics] given and on no other alert topic.
  static void sync(Set<String> topics) {
    if (!_supported) return;
    final key = (topics.toList()..sort()).join(',');
    if (key == _applied) return;
    _applied = key;
    _queue = _queue.then((_) => _apply(topics, key));
  }

  static Future<void> _apply(Set<String> topics, String key) async {
    try {
      final messaging = FirebaseMessaging.instance;
      if (!_asked) {
        _asked = true;
        await messaging.requestPermission();
      }
      for (final t in alertTopics) {
        if (topics.contains(t.key)) {
          await messaging.subscribeToTopic(t.key);
        } else {
          await messaging.unsubscribeFromTopic(t.key);
        }
      }
    } catch (_) {
      // Offline or no Google Play services: try again on the next change.
      if (_applied == key) _applied = null;
    }
  }

  /// Stops every notification on this phone. Called when signing out.
  static Future<void> reset() async {
    _applied = null;
    if (!_supported) return;
    try {
      await _queue;
      await FirebaseMessaging.instance.deleteToken().timeout(
        const Duration(seconds: 6),
      );
    } catch (_) {}
  }

  /// Asks the Apps Script to look for new items now. It finds them itself
  /// (and checks every 10 minutes anyway), so a nudge that fails is harmless.
  static void nudge() {
    final url = AppConfig.notifyUrl;
    if (url.isEmpty) return;
    unawaited(postNudge(url));
  }
}
