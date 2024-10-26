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

  group('Booking Fee', () {
    test(r'Fixed Price - Job with zero Booking Fee, $100 System Fee', () async {
      final now = DateTime.now();
      final job = await createJob(now, BillingType.fixedPrice,
          hourlyRate: MoneyEx.fromInt(5000), bookingFee: MoneyEx.zero);

      await _setSystemBookingFee(MoneyEx.dollars(100));

      // Create invoice for the job
      final invoice = await DaoInvoice().create(job, [], groupByTask: true);

      // Verify that the invoice does not contain a Booking Fee.
      final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
      expect(invoiceLines.length, equals(0));

      // Check invoice totals
      expect(invoice.totalAmount, MoneyEx.fromInt(0));
    });

    test(r'Fixed Price - Job with null Booking Fee, $100 System Fee', () async {
      final now = DateTime.now();
      final job = await createJob(now, BillingType.fixedPrice,
          hourlyRate: MoneyEx.fromInt(5000));

      await _setSystemBookingFee(MoneyEx.dollars(100));

      // Create invoice for the job
      final invoice = await DaoInvoice().create(job, [], groupByTask: true);

      // Verify that the invoice does not contain a Booking Fee.
      final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
      expect(invoiceLines.length, equals(0));

      // Check invoice totals
      expect(invoice.totalAmount, MoneyEx.dollars(0));
    });

    test(r'Fixed Price - Job with $50 Booking Fee, $100 System Fee', () async {
      final now = DateTime.now();
      final job = await createJob(now, BillingType.fixedPrice,
          hourlyRate: MoneyEx.fromInt(5000), bookingFee: MoneyEx.dollars(50));

      await _setSystemBookingFee(MoneyEx.dollars(100));

      // Create invoice for the job
      final invoice = await DaoInvoice().create(job, [], groupByTask: true);

      // Verify that the invoice does not contain a Booking Fee.
      final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
      expect(invoiceLines.length, equals(0));

      // Check invoice totals
      expect(invoice.totalAmount, MoneyEx.dollars(0));
    });

    test('Fixed Price - Job with null Booking Fee, null System Fee', () async {
      final now = DateTime.now();
      final job = await createJob(now, BillingType.fixedPrice,
          hourlyRate: MoneyEx.fromInt(5000));

      await _setSystemBookingFee(MoneyEx.zero);

      // Create invoice for the job
      final invoice = await DaoInvoice().create(job, [], groupByTask: true);

      // Verify that the invoice does not contain a Booking Fee.
      final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
      expect(invoiceLines.length, equals(0));

      // Check invoice totals
      expect(invoice.totalAmount, MoneyEx.fromInt(0));
    });
  });
}

Future<void> _setSystemBookingFee(Money amount) async {
  final system = await DaoSystem().get();
  system!.defaultBookingFee = amount;
  await DaoSystem().update(system);
}
