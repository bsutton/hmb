import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/billing_service.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../../ui/ui_test_helpers.dart';
import '../../util/settings_test_helper.dart';
import 'utility.dart' show createTask, createTimeEntry;

void main() {
  setUpAll(prepareSettingsTest);
  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });
  tearDown(tearDownTestDb);

  test('T&M labour remains available after both fixed milestones', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: MoneyEx.dollars(88),
      bookingFee: MoneyEx.zero,
    );
    final fixed = await createTask(job, 'Original fixed work');
    final quote = Quote.forInsert(
      jobId: job.id,
      summary: 'Original contract',
      description: '',
      totalAmount: MoneyEx.dollars(1000),
      state: QuoteState.approved,
    );
    await DaoQuote().insert(quote);
    await DaoQuoteLineGroup().insert(
      QuoteLineGroup.forInsert(
        quoteId: quote.id,
        taskId: fixed.id,
        name: fixed.name,
      ),
    );
    final milestones = <Milestone>[];
    for (var number = 1; number <= 2; number++) {
      final milestone = Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: number,
        paymentAmount: MoneyEx.dollars(500),
        paymentPercentage: Percentage.fromInt(5000),
      );
      await DaoMilestone().insert(milestone);
      milestones.add(milestone);
    }
    final service = BillingService();
    Future<Invoice> invoiceKeys(Iterable<String> keys) async {
      final preview = await service.preview(job.id);
      return await service.commit(
        preview.select(keys: keys, contactId: job.billingContactId!),
      );
    }

    await invoiceKeys(['milestone:${milestones.first.id}']);
    final extra = await createTask(
      job,
      'Additional T&M work',
      billingType: BillingType.timeAndMaterial,
    );
    final time = await createTimeEntry(
      extra,
      DateTime(2026, 1, 2, 11),
      const Duration(hours: 2),
    );
    await invoiceKeys(['milestone:${milestones.last.id}']);

    // This is the exact data source used by Review Charges.
    final preview = await service.preview(job.id);
    expect(preview.candidates, hasLength(1));
    final charge = preview.candidates.single;
    expect(charge.key, 'time:${time.id}');
    expect(charge.taskId, extra.id);
    expect(charge.amount, MoneyEx.dollars(176));
    final invoice = await service.commit(
      preview.select(keys: [charge.key], contactId: job.billingContactId!),
    );
    expect(invoice.totalAmount, MoneyEx.dollars(176));
    final lines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    expect(lines.single.description, contains('Labour'));
    expect(lines.single.quantity, Fixed.fromNum(2));
    expect(lines.single.unitPrice, MoneyEx.dollars(88));
    expect(lines.single.lineTotal, MoneyEx.dollars(176));
    final groups = await DaoInvoiceLineGroup().getByInvoiceId(invoice.id);
    expect(groups.single.name, extra.name);
    expect((await service.preview(job.id)).candidates, isEmpty);
  });
}
