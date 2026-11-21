import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/photos.dart';
import '../errors.dart';

/// Profile pictures are kept in the database itself, the same way the RFID
/// rickshaw system keeps its photos: shrunk to at most 640 x 640, saved as
/// JPEG at quality 76 and stored as a Base64 data URL. No file storage
/// service (and so no paid Firebase plan) is involved.
///
/// Each picture is its own small document in `photos`. Profiles only hold
/// a short reference to it ("db:<id>"), so lists of people stay light and a
/// picture is downloaded once per phone, then read from the local cache.
class PhotoRepository {
  PhotoRepository(this._db);

  final FirebaseFirestore _db;

  static const maxSide = 640.0;
  static const jpegQuality = 76;
  static const maxBytes = 700 * 1024;
  static const _prefix = 'db:';

  CollectionReference<Map<String, dynamic>> get _photos =>
      _db.collection('photos');

  /// Opens the gallery or camera and returns the shrunk picture.
  static Future<Uint8List?> pick(
    ImageSource source, {
    double side = maxSide,
  }) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: side,
      maxHeight: side,
      imageQuality: jpegQuality,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const AppFailure(
        'That picture is too large to store. Choose a JPG photo instead.',
      );
    }
    return bytes;
  }

  static bool _isPng(Uint8List b) =>
      b.length > 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E;

  /// Saves a picture and returns the reference to put in a profile.
  Future<String> save(Uint8List bytes, String ownerId) async {
    final doc = _photos.doc();
    final type = _isPng(bytes) ? 'image/png' : 'image/jpeg';
    await doc
        .set({
          'image': 'data:$type;base64,${base64Encode(bytes)}',
          'ownerId': ownerId,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 20));
    final ref = '$_prefix${doc.id}';
    Photos.put(ref, bytes);
    return ref;
  }

  /// Reads a picture: from the phone's cache when it is there, otherwise
  /// from the server (once).
  Future<Uint8List?> read(String ref) async {
    if (!ref.startsWith(_prefix)) return null;
    final doc = _photos.doc(ref.substring(_prefix.length));
    Map<String, dynamic>? fields;
    try {
      fields = (await doc.get(const GetOptions(source: Source.cache))).data();
    } catch (_) {
      // Not on this phone yet.
    }
    fields ??= (await doc.get().timeout(const Duration(seconds: 15))).data();
    final data = fields?['image'];
    if (data is! String) return null;
    final comma = data.indexOf(',');
    if (!data.startsWith('data:image/') || comma < 0) return null;
    return base64Decode(data.substring(comma + 1));
  }

  /// Removes a picture that is no longer used. Best effort.
  Future<void> delete(String ref) async {
    if (!ref.startsWith(_prefix)) return;
    try {
      await _photos
          .doc(ref.substring(_prefix.length))
          .delete()
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
}
