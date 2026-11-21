import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';

/// These only OPEN the phone, WhatsApp or Messenger app.
/// Nothing is ever sent automatically.
abstract final class Contact {
  /// Digits in international format without "+", e.g. 8801712345678.
  static String international(String raw) {
    final trimmed = raw.trim();
    var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (trimmed.startsWith('+')) return digits;
    if (digits.startsWith('00')) return digits.substring(2);
    if (digits.startsWith('0')) {
      digits = AppConfig.defaultCountryCode + digits.substring(1);
    }
    return digits;
  }

  static Future<bool> call(String phone) async {
    final cleaned = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return false;
    return _open(Uri(scheme: 'tel', path: cleaned), external: false);
  }

  static Future<bool> whatsApp(String number) async {
    final digits = international(number);
    if (digits.isEmpty) return false;
    return _open(Uri.parse('https://wa.me/$digits'));
  }

  static Future<bool> messenger(String link) async {
    final uri = messengerUri(link);
    if (uri == null) return false;
    return _open(uri);
  }

  /// Accepts m.me/name, facebook.com/name, messenger.com/t/name,
  /// a full https link, or just the username.
  static Uri? messengerUri(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) {
      return Uri.tryParse(v);
    }
    if (v.contains('.') && v.contains('/')) return Uri.tryParse('https://$v');
    final name = v.startsWith('@') ? v.substring(1) : v;
    return Uri.tryParse('https://m.me/${Uri.encodeComponent(name)}');
  }

  static Future<bool> _open(Uri uri, {bool external = true}) async {
    try {
      return await launchUrl(
        uri,
        mode: external
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    } catch (_) {
      return false;
    }
  }
}
