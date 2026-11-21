import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors.dart';
import '../models/models.dart';
import 'admin_repository.dart' show LogActivity;

class NoteRepository {
  NoteRepository(this._db, this._log);

  final FirebaseFirestore _db;
  final LogActivity _log;

  CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection('notes');

  String newId() => _notes.doc().id;

  Stream<List<Note>> watch({int limit = 80}) => _notes
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Note.fromDoc).toList());

  Future<bool> create(
    String id, {
    required String title,
    required String content,
    required String category,
    required bool pinned,
    required bool important,
    required AppUser author,
  }) async {
    final synced = await commit(
      _notes.doc(id).set({
        'title': title,
        'content': content,
        'category': category,
        'pinned': pinned,
        'important': important,
        'authorId': author.id,
        'authorName': author.fullName,
        'authorPhotoUrl': author.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('note.created', 'Posted note "$title"');
    return synced;
  }

  Future<bool> update(
    String id, {
    required String title,
    required String content,
    required String category,
    required bool pinned,
    required bool important,
  }) async {
    final synced = await commit(
      _notes.doc(id).update({
        'title': title,
        'content': content,
        'category': category,
        'pinned': pinned,
        'important': important,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('note.edited', 'Edited note "$title"');
    return synced;
  }

  Future<bool> setPinned(String id, bool pinned, {String label = ''}) async {
    final synced = await commit(
      _notes.doc(id).update({
        'pinned': pinned,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _log('note.pinned', '${pinned ? 'Pinned' : 'Unpinned'} note "$label"');
    return synced;
  }

  /// Ticks a note off (signed with who did it) or reopens it.
  Future<bool> setDone(
    String id,
    bool done,
    AppUser me, {
    String label = '',
  }) async {
    final synced = await commit(
      _notes.doc(id).update({
        'done': done,
        'doneById': done ? me.id : '',
        'doneByName': done ? me.fullName : '',
        'doneAt': done ? FieldValue.serverTimestamp() : null,
      }),
    );
    _log('note.done', '${done ? 'Ticked off' : 'Reopened'} note "$label"');
    return synced;
  }

  Future<bool> delete(String id, {String label = ''}) async {
    final synced = await commit(_notes.doc(id).delete());
    _log('note.deleted', 'Deleted note "$label"');
    return synced;
  }
}
