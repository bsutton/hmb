import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
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

  group('Booking Fee - Time and Materials', () {
    test(
      r'Time and Materials - Job with zero Booking Fee, $100 System Fee',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.fromInt(5000),
          bookingFee: MoneyEx.zero,
        );

        await _setSystemBookingFee(MoneyEx.dollars(100));

        // Create invoice for the job
        final invoice = await createTimeAndMaterialsInvoice(
          job,
          [],
          groupByTask: true,
          billBookingFee: true,
        );

        // Verify that the invoice includes the system Booking Fee.
        final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
        expect(invoiceLines.length, equals(0));

        // Check invoice totals
        expect(invoice.totalAmount, MoneyEx.dollars(0));
      },
    );

    test(
      r'Time and Materials - Job with null Booking Fee, $100 System Fee',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.fromInt(5000),
        );

        await _setSystemBookingFee(MoneyEx.dollars(100));

        // Create invoice for the job
        final invoice = await createTimeAndMaterialsInvoice(
          job,
          [],
          groupByTask: true,
          billBookingFee: true,
        );

        // Verify that the invoice includes the system Booking Fee.
        final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
        expect(invoiceLines.length, equals(1));
        expect(invoiceLines.first.lineTotal, equals(MoneyEx.dollars(100)));

        // Check invoice totals
        expect(invoice.totalAmount, MoneyEx.dollars(100));
      },
    );

    test(
      r'Time and Materials - Job with $50 Booking Fee, $100 System Fee',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.fromInt(5000),
          bookingFee: MoneyEx.dollars(50),
        );

        await _setSystemBookingFee(MoneyEx.dollars(100));

        // Create invoice for the job
        final invoice = await createTimeAndMaterialsInvoice(
          job,
          [],
          groupByTask: true,
          billBookingFee: true,
        );

        // Verify that the invoice includes the job-specific
        //  Booking Fee (ignores system fee).
        final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
        expect(invoiceLines.length, equals(1));
        expect(invoiceLines.first.lineTotal, equals(MoneyEx.dollars(50)));

        // Check invoice totals
        expect(invoice.totalAmount, MoneyEx.dollars(50));
      },
    );

    test(
      'Time and Materials - Job with null Booking Fee, null System Fee',
      () async {
        final now = DateTime.now();
        final job = await createJob(
          now,
          BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.fromInt(5000),
        );

        await _setSystemBookingFee(MoneyEx.zero);

        // Create invoice for the job
        final invoice = await createTimeAndMaterialsInvoice(
          job,
          [],
          groupByTask: true,
          billBookingFee: true,
        );

        // Verify that the invoice does not contain a Booking Fee.
        final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
        expect(invoiceLines.length, equals(0));

        // Check invoice totals
        expect(invoice.totalAmount, MoneyEx.fromInt(0));
      },
    );
  });
}

Future<void> _setSystemBookingFee(Money amount) async {
  final system = await DaoSystem().get();
  system.defaultBookingFee = amount;
  await DaoSystem().update(system);
}
