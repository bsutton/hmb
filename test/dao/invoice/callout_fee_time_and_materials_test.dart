import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../../ui/ui_test_helpers.dart';
import '../../util/settings_test_helper.dart';

void main() {
  setUpAll(prepareSettingsTest);
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  for (final (jobFee, systemFee, expected) in [
    (0, 100, 0),
    (null, 100, 100),
    (50, 100, 50),
    (null, 0, 0),
  ]) {
    test(
      'fee uses job override $jobFee and system fallback $systemFee',
      () async {
        final system = await DaoSystem().getForUpdate();
        system.defaultBookingFee = MoneyEx.dollars(systemFee);
        await DaoSystem().updateConfiguration(system);
        final job = await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
          bookingFee: jobFee == null ? null : MoneyEx.dollars(jobFee),
        );
        final contact = (await DaoContact().getById(job.billingContactId))!;
        final creation = createInvoiceForSelectedTasks(
          job,
          contact,
          [],
          groupByTask: true,
          billBookingFee: true,
        );
        if (expected == 0) {
          await expectLater(creation, throwsException);
          expect(await DaoInvoice().getByJobId(job.id), isEmpty);
        } else {
          final invoice = await creation;
          expect(invoice.totalAmount, MoneyEx.dollars(expected));
          final lines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
          expect(lines.single.fromBookingFee, isTrue);
          await expectLater(
            createInvoiceForSelectedTasks(
              job,
              contact,
              [],
              groupByTask: true,
              billBookingFee: true,
            ),
            throwsException,
          );
        }
      },
    );
  }
}
