import 'dart:collection';
import 'dart:typed_data';

/// In-memory shelf of profile pictures that are already decoded, plus the
/// hook the data layer uses to fetch one that is not on the shelf yet.
abstract final class Photos {
  /// Set once at startup (see main.dart).
  static Future<Uint8List?> Function(String ref) reader = (ref) async => null;

  static const _capacity = 160;
  static final _shelf = LinkedHashMap<String, Uint8List>();
  static final _loading = <String, Future<Uint8List?>>{};

  static Uint8List? cached(String ref) => _shelf[ref];

  static void put(String ref, Uint8List bytes) {
    _shelf.remove(ref);
    _shelf[ref] = bytes;
    if (_shelf.length > _capacity) _shelf.remove(_shelf.keys.first);
  }

  /// Never throws: a picture that cannot be loaded is simply not shown.
  static Future<Uint8List?> load(String ref) {
    final ready = _shelf[ref];
    if (ready != null) return Future.value(ready);
    return _loading[ref] ??= _fetch(ref);
  }

  static Future<Uint8List?> _fetch(String ref) async {
    try {
      final bytes = await reader(ref);
      if (bytes != null && bytes.isNotEmpty) {
        put(ref, bytes);
        return bytes;
      }
    } catch (_) {
      // Offline or removed: the avatar falls back to initials.
    } finally {
      _loading.remove(ref);
    }
    return null;
  }
}
