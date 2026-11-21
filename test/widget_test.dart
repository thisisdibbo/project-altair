import 'package:flutter_test/flutter_test.dart';
import 'package:project_altair/core/utils/format.dart';
import 'package:project_altair/core/utils/launchers.dart';

void main() {
  test('live timer text', () {
    expect(
      formatElapsed(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '01:02:03',
    );
    expect(formatElapsed(const Duration(hours: 100)), '100:00:00');
    expect(formatElapsed(const Duration(seconds: -5)), '00:00:00');
  });

  test('total duration text', () {
    expect(formatDuration(const Duration(hours: 2, minutes: 14)), '2h 14m');
    expect(formatDuration(const Duration(minutes: 14, seconds: 9)), '14m 09s');
    expect(formatDuration(const Duration(seconds: 42)), '42s');
  });

  test('WhatsApp numbers are sent in international format', () {
    expect(Contact.international('01712345678'), '8801712345678');
    expect(Contact.international('+880 1712-345678'), '8801712345678');
    expect(Contact.international('008801712345678'), '8801712345678');
  });

  test('Messenger links accept a link or a username', () {
    expect(Contact.messengerUri('m.me/altair').toString(), 'https://m.me/altair');
    expect(Contact.messengerUri('@altair').toString(), 'https://m.me/altair');
    expect(
      Contact.messengerUri('https://www.facebook.com/altair').toString(),
      'https://www.facebook.com/altair',
    );
    expect(Contact.messengerUri('  '), isNull);
  });
}
