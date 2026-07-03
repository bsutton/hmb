import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('job receipt allocation is emitted as an invoice line', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.dollars(90),
    );
    final billingContact = (await DaoContact().getById(job.contactId))!;
    final supplierId = await DaoSupplier().insert(
      Supplier.forInsert(
        name: 'Paint Shop',
        businessNumber: null,
        description: null,
        bsb: null,
        accountNumber: null,
        service: null,
      ),
    );
    final receiptId = await DaoReceipt().insert(
      Receipt.forInsert(
        receiptDate: DateTime(2026, 1, 2),
        jobId: job.id,
        supplierId: supplierId,
        totalExcludingTax: MoneyEx.dollars(25),
        tax: MoneyEx.fromInt(250),
        totalIncludingTax: MoneyEx.fromInt(2750),
      ),
    );

    final invoice = await createInvoiceForSelectedTasks(
      job,
      billingContact,
      const [],
      groupByTask: true,
      billBookingFee: false,
    );

    final lines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    expect(lines, hasLength(1));
    expect(lines.single.description, contains('Receipt #$receiptId'));
    expect(lines.single.description, contains('Paint Shop'));
    expect(lines.single.lineTotal, MoneyEx.dollars(25));

    final allocations = await DaoReceipt().getJobAllocations(receiptId);
    expect(allocations.single.invoiceLineId, lines.single.id);

    await DaoInvoiceLine().deleteByInvoiceId(invoice.id);
    final unbilledAllocations = await DaoReceipt().getJobAllocations(receiptId);
    expect(unbilledAllocations.single.invoiceLineId, isNull);
  });
}
