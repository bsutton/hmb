import 'package:hmb/util/dart/app_settings.dart';
import 'package:test/test.dart';

import 'settings_test_helper.dart';

void main() {
  setUpAll(prepareSettingsTest);

  setUp(() async {
    await resetSettingsForTest();
  });

  test('Google Calendar sync defaults on and can be disabled', () async {
    expect(await AppSettings.getGoogleCalendarSyncEnabled(), isTrue);

    await AppSettings.setGoogleCalendarSyncEnabled(enabled: false);

    expect(await AppSettings.getGoogleCalendarSyncEnabled(), isFalse);
  });
}
