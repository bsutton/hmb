// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/_index.g.dart';
import 'package:money2/money2.dart';

import '../../database/management/db_utility_test.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  group('Booking Fee', () {
    //   test(r'Fixed Price - Job with zero Booking Fee, $100 System Fee', () async {
    //     final now = DateTime.now();
    //     final job = await createJob(now, BillingType.fixedPrice,
    //         hourlyRate: MoneyEx.fromInt(5000), bookingFee: MoneyEx.zero);

    //     await _setSystemBookingFee(MoneyEx.dollars(100));

    //     // Create invoice for the job
    //     final invoice = await createFixedPriceInvoice(
    //         job, 'Full Amount', Percentage.onehundred, null);

    //     // Invoice should just have a single progress payment line.
    //     final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    //     expect(invoiceLines.length, equals(1));

    //     // Check invoice totals
    //     expect(invoice.totalAmount, MoneyEx.fromInt(0));
    //   });

    //   test(r'Fixed Price - Job with null Booking Fee, $100 System Fee', () async {
    //     final now = DateTime.now();
    //     final job = await createJob(now, BillingType.fixedPrice,
    //         hourlyRate: MoneyEx.fromInt(5000));

    //     await _setSystemBookingFee(MoneyEx.dollars(100));

    //     // Create invoice for the job
    //     final invoice = await createFixedPriceInvoice(
    //         job, 'Full Amount', Percentage.onehundred, null);

    //     // Invoice should just have a single progress payment line.
    //     final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    //     expect(invoiceLines.length, equals(1));

    //     // Check invoice totals
    //     expect(invoice.totalAmount, MoneyEx.dollars(0));
    //   });

    //   test(r'Fixed Price - Job with $50 Booking Fee, $100 System Fee', () async {
    //     final now = DateTime.now();
    //     final job = await createJob(now, BillingType.fixedPrice,
    //         hourlyRate: MoneyEx.fromInt(5000), bookingFee: MoneyEx.dollars(50));

    //     await _setSystemBookingFee(MoneyEx.dollars(100));

    //     // Create invoice for the job
    //     final invoice = await createFixedPriceInvoice(
    //         job, 'Full Amount', Percentage.fromInt(10000), null);

    //     // Invoice should just have a single progress payment line.
    //     final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    //     expect(invoiceLines.length, equals(1));

    //     // Check invoice totals
    //     expect(invoice.totalAmount, MoneyEx.dollars(0));
    //   });

    //   test('Fixed Price - Job with null Booking Fee, null System Fee', () async {
    //     final now = DateTime.now();
    //     final job = await createJob(now, BillingType.fixedPrice,
    //         hourlyRate: MoneyEx.fromInt(5000));

    //     await _setSystemBookingFee(MoneyEx.zero);

    //     // Create invoice for the job
    //     final invoice = await createFixedPriceInvoice(
    //         job, 'Full Amount', Percentage.fromInt(10000), null);

    //     // Invoice should just have a single progress payment line.
    //     final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    //     expect(invoiceLines.length, equals(1));

    //     // Check invoice totals
    //     expect(invoice.totalAmount, MoneyEx.fromInt(0));
    //   });
  });
}

Future<void> _setSystemBookingFee(Money amount) async {
  final system = await DaoSystem().get();
  system!.defaultBookingFee = amount;
  await DaoSystem().update(system);
}
