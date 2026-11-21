class AppConfig {
  static const appName = 'Project Altair';
  static const version = '1.1.0';

  /// Members sign in with a User ID. Firebase sign-in needs a name shaped
  /// like an e-mail address, so the app adds this ending behind the scenes.
  /// example.com is a reserved name: no mail can ever be delivered to it.
  static const loginDomain = 'altair.example.com';

  /// Used when a phone number is typed in local format (leading 0).
  static const defaultCountryCode = '880';

  /// The Web app URL of tools/apps-script/Code.gs (ends in /exec).
  /// Empty: closed-app notifications and the expense sheet wait for the
  /// script's own 10-minute check.
  static const notifyUrl = 'https://script.google.com/macros/s/AKfycbz2ykZ18Z--M-61KjYM-KVgSc9PCIHavtcLE9u5Hrzos4qQiT6mVeF7yW19qDud9gft/exec';

  /// flutter run --dart-define=ALTAIR_EMULATORS=true
  static const useEmulators = bool.fromEnvironment('ALTAIR_EMULATORS');

  /// 10.0.2.2 reaches the host PC from the Android emulator.
  /// For a real phone pass your PC's LAN IP with
  /// --dart-define=ALTAIR_EMULATOR_HOST=192.168.x.x
  static const emulatorHost = String.fromEnvironment(
    'ALTAIR_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
}
