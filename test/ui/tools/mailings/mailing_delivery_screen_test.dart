@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/tools/mailings/mailing_delivery_screen.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test(
    'No Mail skips delivery, excludes future mail, and can be undone',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: MoneyEx.zero,
        summary: 'Mailing customer',
      );
      final mailing = Mailing.forInsert(
        name: 'Road delivery',
        labelLayoutId: 'custom',
      );
      await DaoMailing().insert(mailing);
      final recipient = MailingRecipient.forInsert(
        mailingId: mailing.id,
      customerId: job.customerId!,
        contactId: null,
        siteId: null,
        contactName: 'Alex Example',
        customerName: 'Example Customer',
        siteName: null,
        addressLine1: '1 Main Road',
        addressLine2: '',
        suburb: 'Melbourne',
        state: 'VIC',
        postcode: '3000',
        routeOrder: 0,
      );
      await DaoMailingRecipient().insert(recipient);

      final change = await markNoMailForDelivery(recipient);

      expect(change, isNotNull);
      expect(
        (await DaoCustomer().getById(job.customerId))!.excludeFromMailings,
        isTrue,
      );
      expect(
        (await DaoMailingRecipient().getById(recipient.id))!.deliveryStatus,
        MailingDeliveryStatus.skipped,
      );

      await change!.undo();

      expect(
        (await DaoCustomer().getById(job.customerId))!.excludeFromMailings,
        isFalse,
      );
      expect(
        (await DaoMailingRecipient().getById(recipient.id))!.deliveryStatus,
        MailingDeliveryStatus.pending,
      );
    },
  );
}
