import 'dart:js_interop';

@JS('fetch')
external JSPromise<JSAny?> _fetch(JSString url, JSAny? init);

/// Browsers: a "no-cors" request. The Apps Script still runs; the browser
/// just does not let the app read its answer, which it does not need.
Future<void> postNudge(String url) async {
  try {
    await _fetch(
      url.toJS,
      {'method': 'POST', 'mode': 'no-cors', 'body': '{}'}.jsify(),
    ).toDart;
  } catch (_) {}
}
