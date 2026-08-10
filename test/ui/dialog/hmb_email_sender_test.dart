import 'dart:io';

import 'package:hmb/dao/dao_system.dart';
import 'package:hmb/entity/system.dart';
import 'package:hmb/ui/dialog/hmb_email_sender.dart';
import 'package:hmb/util/dart/exceptions.dart';
import 'package:test/test.dart';

import '../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('smtp settings check explains missing configuration', () {
    expect(
      () => HMBEmailSender().checkSettings(),
      throwsA(
        isA<HMBException>().having(
          (e) => e.message,
          'message',
          contains('Settings | Integrations | SMTP Email'),
        ),
      ),
    );
  });

  test('gmail oauth explains missing desktop client id', () async {
    if (!(Platform.isLinux || Platform.isWindows)) {
      return;
    }

    final system = await DaoSystem().getForUpdate();
    system
      ..smtpProvider = SmtpProvider.gmail
      ..smtpAuthMode = SmtpAuthMode.googleOAuth
      ..smtpUsername = 'sender@example.com'
      ..smtpFromEmail = 'sender@example.com';
    await DaoSystem().updateConfiguration(system);

    expect(
      () => HMBEmailSender().checkSettings(),
      throwsA(
        isA<HMBException>().having(
          (e) => e.message,
          'message',
          contains('Desktop OAuth client ID'),
        ),
      ),
    );
  });
}
