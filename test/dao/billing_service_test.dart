import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/billing_service.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/invoice_lifecycle_service.dart';
import 'package:hmb/dao/task_fixed_agreement.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';
import '../util/settings_test_helper.dart';
import 'invoice/utility.dart' show insertMaterialItem;

void main() {
  setUpAll(prepareSettingsTest);
  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });
  tearDown(tearDownTestDb);

  Future<Task> fixedTask(Job job) async {
    final task = Task.forInsert(
      jobId: job.id,
      name: 'On-site addition',
      description: '',
      billingType: BillingType.fixedPrice,
      status: TaskStatus.completed,
    );
    await DaoTask().insert(task);
    await DaoTask().db.transaction(
      (txn) => TaskFixedAgreement().save(
        txn,
        task,
        MoneyEx.dollars(80),
        'Agreed on site',
      ),
    );
    return task;
  }

  for (final type in [BillingType.fixedPrice, BillingType.timeAndMaterial]) {
    test(
      'on-site fixed addition and actuals share an invoice on ${type.name}',
      () async {
        final job = await createJobWithCustomer(
          billingType: type,
          hourlyRate: MoneyEx.dollars(100),
          bookingFee: MoneyEx.zero,
        );
        final fixed = await fixedTask(job);
        // Delivery time for agreed work is a cost, never an extra charge.
        await DaoTimeEntry().insert(
          TimeEntry.forInsert(
            taskId: fixed.id,
            startTime: DateTime(2026, 1, 1, 9),
            endTime: DateTime(2026, 1, 1, 10),
          ),
        );
        final actual = Task.forInsert(
          jobId: job.id,
          name: 'Actual work',
          description: '',
          billingType: BillingType.timeAndMaterial,
          status: TaskStatus.completed,
        );
        await DaoTask().insert(actual);
        await DaoTimeEntry().insert(
          TimeEntry.forInsert(
            taskId: actual.id,
            startTime: DateTime(2026, 1, 1, 9),
            endTime: DateTime(2026, 1, 1, 10),
          ),
        );
        final service = BillingService();
        final preview = await service.preview(job.id);
        expect(
          preview.candidates.map((c) => c.kind),
          unorderedEquals(['task_scope', 'time']),
        );
        final plan = preview.select(
          keys: preview.candidates.map((c) => c.key),
          contactId: job.billingContactId!,
        );
        expect(plan.total, MoneyEx.dollars(180));
        final invoice = await service.commit(plan);
        expect((await service.commit(plan)).id, invoice.id);
        expect((await service.preview(job.id)).candidates, isEmpty);
        expect(
          (await DaoTimeEntry().getByTask(fixed.id)).single.billed,
          isFalse,
        );
        await InvoiceLifecycleService().deleteDraft(invoice.id);
        expect((await service.preview(job.id)).candidates, hasLength(2));
      },
    );
  }

  test('fractional materials retain exact cents on invoice lines', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      bookingFee: MoneyEx.zero,
    );
    final task = Task.forInsert(
      jobId: job.id,
      name: 'Materials',
      description: '',
      billingType: BillingType.timeAndMaterial,
      status: TaskStatus.completed,
    );
    await DaoTask().insert(task);
    await insertMaterialItem(
      task,
      itemType: TaskItemType.materialsBuy,
      actualQuantity: Fixed.fromNum(1.235, decimalDigits: 3),
      actualUnitCost: MoneyEx.dollars(100),
    );
    final service = BillingService();
    final preview = await service.preview(job.id);
    final invoice = await service.commit(
      preview.select(
        keys: preview.candidates.map((c) => c.key),
        contactId: job.billingContactId!,
      ),
    );
    final line = (await DaoInvoiceLine().getByInvoiceId(invoice.id)).single;
    expect(invoice.totalAmount, MoneyEx.fromInt(12350));
    expect(line.unitPrice.multiplyByFixed(line.quantity), line.lineTotal);
    await DaoInvoice().recalculateTotal(invoice.id);
    expect(
      (await DaoInvoice().getById(invoice.id))!.totalAmount,
      invoice.totalAmount,
    );
  });

  test(
    'discount creates its group atomically and rejects issued edits',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        bookingFee: MoneyEx.zero,
      );
      await fixedTask(job);
      final service = BillingService();
      final preview = await service.preview(job.id);
      final invoice = await service.commit(
        preview.select(
          keys: preview.candidates.map((c) => c.key),
          contactId: job.billingContactId!,
        ),
      );
      final discount = await DaoInvoice().addDiscountLine(
        invoice: invoice,
        amount: MoneyEx.dollars(10),
      );
      expect(discount.invoiceLineGroupId, greaterThan(0));
      final discounted = (await DaoInvoice().getById(invoice.id))!;
      expect(discounted.totalAmount, MoneyEx.dollars(70));
      discounted.sent = true;
      await DaoInvoice().update(discounted);
      await expectLater(
        DaoInvoice().addDiscountLine(
          invoice: discounted,
          amount: MoneyEx.dollars(5),
        ),
        throwsException,
      );
      expect(await DaoInvoiceLine().getByInvoiceId(invoice.id), hasLength(2));
    },
  );

  test('stale price rejects commit without leaving a draft', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      bookingFee: MoneyEx.zero,
    );
    final task = await fixedTask(job);
    final service = BillingService();
    final preview = await service.preview(job.id);
    final plan = preview.select(
      keys: preview.candidates.map((c) => c.key),
      contactId: job.billingContactId!,
    );
    await DaoTask().db.transaction(
      (txn) => TaskFixedAgreement().save(
        txn,
        task,
        MoneyEx.dollars(90),
        'Revised agreement',
      ),
    );
    await expectLater(service.commit(plan), throwsException);
    expect(
      await DaoTask().db.query(
        'invoice',
        where: 'job_id = ?',
        whereArgs: [job.id],
      ),
      isEmpty,
    );
  });

  test('invoice history protects fixed agreement and billing mode', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      bookingFee: MoneyEx.zero,
    );
    final task = await fixedTask(job);
    final service = BillingService();
    final preview = await service.preview(job.id);
    await service.commit(
      preview.select(
        keys: preview.candidates.map((c) => c.key),
        contactId: job.billingContactId!,
      ),
    );
    await expectLater(
      DaoTask().db.transaction(
        (txn) => TaskFixedAgreement().save(
          txn,
          task,
          MoneyEx.dollars(90),
          'Changed',
        ),
      ),
      throwsException,
    );
    await expectLater(
      DaoTask().update(task.copyWith(billingType: BillingType.timeAndMaterial)),
      throwsException,
    );
  });
  test(
    'failure during source claim rolls back invoice and source writes',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        bookingFee: MoneyEx.zero,
      );
      await fixedTask(job);
      final service = BillingService();
      final preview = await service.preview(job.id);
      final plan = preview.select(
        keys: preview.candidates.map((c) => c.key),
        contactId: job.billingContactId!,
      );
      await DaoTask().db.execute("""
CREATE TEMP TRIGGER fail_claim BEFORE INSERT ON billing_allocation
BEGIN SELECT RAISE(ABORT, 'injected failure'); END
""");
      await expectLater(service.commit(plan), throwsException);
      await DaoTask().db.execute('DROP TRIGGER fail_claim');
      expect(
        await DaoTask().db.query(
          'invoice',
          where: 'job_id = ?',
          whereArgs: [job.id],
        ),
        isEmpty,
      );
      expect((await service.preview(job.id)).candidates, hasLength(1));
      expect((await service.commit(plan)).totalAmount, MoneyEx.dollars(80));
    },
  );

  test('two separate plans cannot claim the same fixed addition', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      bookingFee: MoneyEx.zero,
    );
    await fixedTask(job);
    final service = BillingService();
    final preview = await service.preview(job.id);
    InvoicePlan plan() => preview.select(
      keys: preview.candidates.map((c) => c.key),
      contactId: job.billingContactId!,
    );
    final first = plan();
    final second = plan();
    await service.commit(first);
    await expectLater(service.commit(second), throwsException);
    expect(await DaoTask().db.query('billing_allocation'), hasLength(1));
  });

  for (final defaultType in [
    BillingType.fixedPrice,
    BillingType.timeAndMaterial,
  ]) {
    test('progress quote plus actual variation stays separate '
        'on ${defaultType.name}', () async {
      final job = await createJobWithCustomer(
        billingType: defaultType,
        hourlyRate: MoneyEx.dollars(100),
        bookingFee: MoneyEx.zero,
      );
      final fixed = Task.forInsert(
        jobId: job.id,
        name: 'Agreed scope',
        description: '',
        billingType: BillingType.fixedPrice,
        status: TaskStatus.completed,
      );
      await DaoTask().insert(fixed);
      final quote = Quote.forInsert(
        jobId: job.id,
        summary: 'Contract',
        description: '',
        totalAmount: MoneyEx.dollars(10000),
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
      final deposit = Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: 1,
        paymentAmount: MoneyEx.dollars(3000),
        paymentPercentage: Percentage.fromInt(30),
      );
      final finalPayment = Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: 2,
        paymentAmount: MoneyEx.dollars(7000),
        paymentPercentage: Percentage.fromInt(70),
        dueDate: LocalDate.today().add(const Duration(days: 30)),
      );
      await DaoMilestone().insert(deposit);
      await DaoMilestone().insert(finalPayment);
      final service = BillingService();
      var preview = await service.preview(job.id);
      expect(
        () => preview.select(
          keys: ['milestone:${finalPayment.id}'],
          contactId: job.billingContactId!,
        ),
        throwsException,
      );
      await service.commit(
        preview.select(
          keys: ['milestone:${deposit.id}'],
          contactId: job.billingContactId!,
        ),
      );
      final variation = Task.forInsert(
        jobId: job.id,
        name: 'Additional work',
        description: '',
        billingType: BillingType.timeAndMaterial,
        status: TaskStatus.completed,
      );
      await DaoTask().insert(variation);
      await DaoTimeEntry().insert(
        TimeEntry.forInsert(
          taskId: variation.id,
          startTime: DateTime(2026, 1, 1, 9),
          endTime: DateTime(2026, 1, 1, 17),
        ),
      );
      // Actual hours on the original fixed scope remain covered by the quote.
      await DaoTimeEntry().insert(
        TimeEntry.forInsert(
          taskId: fixed.id,
          startTime: DateTime(2026, 1, 1, 9),
          endTime: DateTime(2026, 1, 1, 17),
        ),
      );
      preview = await service.preview(job.id);
      expect(
        preview.candidates.map((c) => c.kind),
        unorderedEquals(['milestone', 'time']),
      );
      final invoice = await service.commit(
        preview.select(
          keys: preview.candidates.map((c) => c.key),
          contactId: job.billingContactId!,
          allowEarlyBilling: true,
        ),
      );
      expect(invoice.totalAmount, MoneyEx.dollars(7800));
      expect(
        (await DaoMilestone().getById(finalPayment.id))!.paymentAmount,
        MoneyEx.dollars(7000),
      );
      await expectLater(
        DaoQuote().update(quote.copyWith(totalAmount: MoneyEx.dollars(10800))),
        throwsException,
      );
      await InvoiceLifecycleService().deleteDraft(invoice.id);
      expect((await service.preview(job.id)).candidates, hasLength(2));
    });
  }
}
