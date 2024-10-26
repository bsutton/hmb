import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/_index.g.dart';
import 'package:hmb/entity/_index.g.dart';
import 'package:hmb/util/money_ex.dart';
import 'package:money2/money2.dart';

import '../../database/management/db_utility_test.dart';
import 'utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });
  group('Callout Fee', () {
    test(r'Fixed Price - Job with zero callout fee, $100 System Fee', () async {
      final now = DateTime.now();
      final job = await createJob(now, BillingType.fixedPrice,
          hourlyRate: MoneyEx.fromInt(5000), callOutFee: MoneyEx.zero);

      final system = await DaoSystem().get();
      system!.defaultCallOutFee = MoneyEx.dollars(100);
      await DaoSystem().update(system);

      // Create invoice for the job
      final invoice = await DaoInvoice().create(job, [], groupByTask: true);

      // Verify that the invoice does not contain a callout fee.
      final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
      expect(invoiceLines.length, equals(0));

      // Check invoice totals
      expect(invoice.totalAmount, MoneyEx.fromInt(0));
    });

    test(r'Fixed Price - Job with null callout fee, $100 System Fee', () async {
      final now = DateTime.now();
      final job = await createJob(now, BillingType.fixedPrice,
          hourlyRate: MoneyEx.fromInt(5000), callOutFee: MoneyEx.zero);

      await _setSystemCalloutFee(MoneyEx.dollars(100));

      // Create invoice for the job
      final invoice = await DaoInvoice().create(job, [], groupByTask: true);

      // Verify that the invoice does not contain a callout fee.
      final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
      expect(invoiceLines.length, equals(0));

      // Check invoice totals
      expect(invoice.totalAmount, MoneyEx.fromInt(0));
    });
  });
}

Future<void> _setSystemCalloutFee(Money amount) async {
  final system = await DaoSystem().get();
  system!.defaultCallOutFee = amount;
  await DaoSystem().update(system);
}
