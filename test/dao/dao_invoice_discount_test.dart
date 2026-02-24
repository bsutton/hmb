import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/exceptions.dart';
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
    'addDiscountLine inserts negative line and updates invoice total',
    () async {
      final invoice = await _insertInvoiceWithLine(total: 10000);

      final line = await DaoInvoice().addDiscountLine(
        invoice: invoice,
        amount: Money.fromInt(2000, isoCode: 'AUD'),
        description: 'Returned materials',
      );

      expect(line.lineTotal, Money.fromInt(-2000, isoCode: 'AUD'));
      expect(line.unitPrice, Money.fromInt(-2000, isoCode: 'AUD'));
      expect(line.quantity, Fixed.one);

      final updatedInvoice = await DaoInvoice().getById(invoice.id);
      expect(updatedInvoice?.totalAmount, Money.fromInt(8000, isoCode: 'AUD'));
    },
  );

  test('addDiscountLine rejects non-positive amounts', () async {
    final invoice = await _insertInvoiceWithLine(total: 10000);

    expect(
      () =>
          DaoInvoice().addDiscountLine(invoice: invoice, amount: MoneyEx.zero),
      throwsA(isA<HMBException>()),
    );
  });
}

Future<Invoice> _insertInvoiceWithLine({required int total}) async {
  final job = await createJobWithCustomer(
    billingType: BillingType.timeAndMaterial,
    hourlyRate: MoneyEx.zero,
    summary: 'Invoice discount test',
  );

  final invoice = Invoice.forInsert(
    jobId: job.id,
    dueDate: LocalDate.today(),
    totalAmount: Money.fromInt(total, isoCode: 'AUD'),
    billingContactId: job.billingContactId,
  );
  await DaoInvoice().insert(invoice);

  final group = InvoiceLineGroup.forInsert(
    invoiceId: invoice.id,
    name: 'Labour',
  );
  await DaoInvoiceLineGroup().insert(group);

  final line = InvoiceLine.forInsert(
    invoiceId: invoice.id,
    invoiceLineGroupId: group.id,
    description: 'Labour',
    quantity: Fixed.one,
    unitPrice: Money.fromInt(total, isoCode: 'AUD'),
    lineTotal: Money.fromInt(total, isoCode: 'AUD'),
  );
  await DaoInvoiceLine().insert(line);
  await DaoInvoice().recalculateTotal(invoice.id);

  return (await DaoInvoice().getById(invoice.id))!;
}
