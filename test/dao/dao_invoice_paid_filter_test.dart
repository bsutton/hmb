import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test(
    'getByFilter excludes paid invoices when includePaid is false',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Invoice paid filter job',
      );

      final unpaid = Invoice.forInsert(
        jobId: job.id,
        dueDate: LocalDate.today(),
        totalAmount: Money.fromInt(1000, isoCode: 'AUD'),
        billingContactId: job.billingContactId,
      );
      await DaoInvoice().insert(unpaid);
      await DaoInvoice().update(unpaid.copyWith(invoiceNum: 'INV-UNPAID'));

      final paid = Invoice.forInsert(
        jobId: job.id,
        dueDate: LocalDate.today(),
        totalAmount: Money.fromInt(2000, isoCode: 'AUD'),
        billingContactId: job.billingContactId,
        sent: true,
        paid: true,
        paidDate: DateTime.now(),
      );
      await DaoInvoice().insert(paid);
      await DaoInvoice().update(paid.copyWith(invoiceNum: 'INV-PAID'));

      final hiddenPaid = await DaoInvoice().getByFilter(
        null,
        includePaid: false,
      );
      final all = await DaoInvoice().getByFilter(null);

      expect(hiddenPaid.map((i) => i.invoiceNum), isNot(contains('INV-PAID')));
      expect(hiddenPaid.map((i) => i.invoiceNum), contains('INV-UNPAID'));
      expect(
        all.map((i) => i.invoiceNum),
        containsAll(['INV-UNPAID', 'INV-PAID']),
      );
    },
  );
}
