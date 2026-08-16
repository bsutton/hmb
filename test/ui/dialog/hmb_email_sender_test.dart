import 'package:hmb/dao/dao_system.dart';
import 'package:hmb/entity/system.dart';
import 'package:hmb/ui/dialog/google_mail_auth.dart';
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

  test('direct sending is offered only when SMTP is configured', () async {
    final sender = HMBEmailSender();
    expect(await sender.canSendDirectly(), isFalse);

    final system = await DaoSystem().getForUpdate();
    system
      ..smtpProvider = SmtpProvider.gmail
      ..smtpAuthMode = SmtpAuthMode.googleOAuth;
    await DaoSystem().updateConfiguration(system);

    expect(await sender.canSendDirectly(), isTrue);
  });

  test('gmail oauth ships the HMB desktop client id', () {
    expect(
      GoogleMailAuth.desktopClientId,
      '704526923643-klt8djil7tdulg1ab4v70qdd3ff4515p.'
      'apps.googleusercontent.com',
    );
  });
}
