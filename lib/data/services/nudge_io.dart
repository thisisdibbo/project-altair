import 'dart:io';

/// Phones: a plain HTTP POST to the Apps Script.
Future<void> postNudge(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.postUrl(Uri.parse(url));
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.write('{}');
    final response = await request.close().timeout(
      const Duration(seconds: 30),
    );
    await response.drain<void>();
  } catch (_) {
  } finally {
    client.close(force: true);
  }
}
