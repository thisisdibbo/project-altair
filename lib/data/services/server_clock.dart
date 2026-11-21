import 'package:cloud_firestore/cloud_firestore.dart';

/// Task timers show (server time now) - (server start time). The phone's own
/// clock may be wrong, so we measure how far it is from the server once per
/// session and correct for it.
class ServerClock {
  ServerClock(this._db);

  final FirebaseFirestore _db;

  Duration _offset = Duration.zero;

  DateTime now() => DateTime.now().add(_offset);

  Future<void> sync(String uid) async {
    try {
      final ref = _db.collection('clockSync').doc(uid);
      final sent = DateTime.now();
      await ref
          .set({'ts': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 6));
      final acked = DateTime.now();
      final snap = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 6));
      final ts = snap.data()?['ts'];
      if (ts is Timestamp) {
        final midpoint = sent.add(
          Duration(microseconds: acked.difference(sent).inMicroseconds ~/ 2),
        );
        _offset = ts.toDate().difference(midpoint);
      }
    } catch (_) {
      // Offline: keep the previous offset. Timers still run from the
      // server start time and correct themselves on the next sync.
    }
  }
}
