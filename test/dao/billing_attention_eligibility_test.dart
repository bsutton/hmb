import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/billing_attention_cache.dart';
import 'package:hmb/dao/billing_queue.dart';
import 'package:hmb/dao/billing_service.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';
import '../util/settings_test_helper.dart';

void main() {
  late Job job;
  late Quote quote;
  setUpAll(prepareSettingsTest);
  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
    job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      status: JobStatus.completed,
      hourlyRate: MoneyEx.dollars(100),
      bookingFee: MoneyEx.zero,
    );
    quote = Quote.forInsert(
      jobId: job.id,
      summary: 'Historical quote',
      description: '',
      totalAmount: MoneyEx.dollars(100),
      state: QuoteState.invoiced,
    );
    await DaoQuote().insert(quote);
  });
  tearDown(tearDownTestDb);

  test(
    'uncertain historical billing remains reviewable, not ready to invoice',
    () async {
      final preview = await BillingService().preview(job.id);
      expect(preview.candidates, isEmpty);
      expect(preview.blocked.single, contains('review historical billing'));
      await BillingQueue(testDb!).drain(limit: 10000);
      expect(
        (await DaoJob().readyToBeInvoiced(null)).map((job) => job.id),
        isNot(contains(job.id)),
      );
      final cache = BillingAttentionCache();
      addTearDown(cache.dispose);
      await cache.refresh();
      final entry = cache.entries!.singleWhere(
        (entry) => entry.job.id == job.id,
      );
      expect(entry.canInvoice, isFalse);
    },
  );

  test(
    'fully invoiced milestones do not warn about a previously billed fee',
    () async {
      job.bookingFeeInvoiced = true;
      await DaoJob().update(job);
      await DaoQuoteLineGroup().insert(
        QuoteLineGroup.forInsert(
          quoteId: quote.id,
          taskId: null,
          name: 'Booking Fee',
        ),
      );
      final invoice = Invoice.forInsert(
        jobId: job.id,
        totalAmount: MoneyEx.dollars(100),
        dueDate: LocalDate.today(),
        billingContactId: job.billingContactId,
      );
      await DaoInvoice().insert(invoice);
      await DaoMilestone().insert(
        Milestone.forInsert(
          quoteId: quote.id,
          invoiceId: invoice.id,
          milestoneNumber: 1,
          paymentAmount: MoneyEx.dollars(100),
          paymentPercentage: Percentage.fromInt(100),
        ),
      );
      final preview = await BillingService().preview(job.id);
      expect(preview.candidates, isEmpty);
      expect(preview.blocked, isEmpty);
    },
  );

  test('partially invoiced quotes retain their open milestone', () async {
    final invoice = Invoice.forInsert(
      jobId: job.id,
      totalAmount: MoneyEx.dollars(50),
      dueDate: LocalDate.today(),
      billingContactId: job.billingContactId,
    );
    await DaoInvoice().insert(invoice);
    await DaoMilestone().insert(
      Milestone.forInsert(
        quoteId: quote.id,
        invoiceId: invoice.id,
        milestoneNumber: 1,
        paymentAmount: MoneyEx.dollars(50),
        paymentPercentage: Percentage.fromInt(50),
      ),
    );
    await DaoMilestone().insert(
      Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: 2,
        paymentAmount: MoneyEx.dollars(50),
        paymentPercentage: Percentage.fromInt(50),
      ),
    );
    final preview = await BillingService().preview(job.id);
    expect(preview.candidates.single.kind, 'milestone');
    expect(preview.candidates.single.amount, MoneyEx.dollars(50));
  });

  test(
    'unlinked milestones do not override uncertain historical billing',
    () async {
      await DaoMilestone().insert(
        Milestone.forInsert(
          quoteId: quote.id,
          milestoneNumber: 1,
          paymentAmount: MoneyEx.dollars(100),
          paymentPercentage: Percentage.fromInt(100),
        ),
      );
      final preview = await BillingService().preview(job.id);
      expect(preview.candidates, isEmpty);
      expect(preview.blocked.single, contains('review historical billing'));
    },
  );

  test('no-charge time does not create an invoicing reminder', () async {
    job.billingType = BillingType.timeAndMaterial;
    await DaoJob().update(job);
    final task = Task.forInsert(
      jobId: job.id,
      name: 'Complimentary work',
      description: '',
      status: TaskStatus.completed,
    );
    await DaoTask().insert(task);
    await DaoTimeEntry().insert(
      TimeEntry.forInsert(
        taskId: task.id,
        startTime: DateTime(2026, 1, 1, 9),
        endTime: DateTime(2026, 1, 1, 10),
        billable: false,
        showOnInvoice: true,
      ),
    );
    final readiness = await JobBillingReadinessService().evaluate(job);
    expect(readiness.canInvoice, isFalse);
  });
}
