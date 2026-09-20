import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test(
    'completed T&M job remains ready until accrued work is billed',
    () async {
      final job = await _job(
        BillingType.timeAndMaterial,
        status: JobStatus.completed,
      );
      final task = Task.forInsert(
        jobId: job.id,
        name: 'Labour',
        description: '',
        status: TaskStatus.approved,
      );
      await DaoTask().insert(task);
      final entry = TimeEntry.forInsert(
        taskId: task.id,
        startTime: DateTime(2025, 1, 1, 9),
        endTime: DateTime(2025, 1, 1, 10),
      );
      await DaoTimeEntry().insert(entry);

      var readiness = await JobBillingReadinessService().evaluate(job);
      expect(readiness.needsAttention, isTrue);
      expect(
        readiness.reasons.map((reason) => reason.code),
        contains(JobBillingReasonCode.unbilledTimeAndMaterials),
      );
      expect(
        (await DaoJob().readyToBeInvoiced(null)).map((item) => item.id),
        contains(job.id),
      );

      await DaoTimeEntry().update(entry.copyWith(billed: true));
      readiness = await JobBillingReadinessService().evaluate(job);
      expect(readiness.needsAttention, isFalse);
    },
  );

  test('fixed job reports milestones and unallocated quote amount', () async {
    final job = await _job(BillingType.fixedPrice, status: JobStatus.completed);
    final quote = Quote.forInsert(
      jobId: job.id,
      summary: 'Approved quote',
      description: '',
      totalAmount: MoneyEx.fromInt(100000),
      state: QuoteState.approved,
    );
    await DaoQuote().insert(quote);
    await DaoMilestone().insert(
      Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: 1,
        paymentAmount: MoneyEx.fromInt(60000),
        paymentPercentage: Percentage.fromInt(60),
      ),
    );

    final readiness = await JobBillingReadinessService().evaluate(job);
    expect(
      readiness.reasons.map((reason) => reason.code),
      containsAll([
        JobBillingReasonCode.uninvoicedMilestone,
        JobBillingReasonCode.unallocatedQuoteAmount,
      ]),
    );
  });

  test(
    'completed fixed job without approved quote needs billing setup',
    () async {
      final job = await _job(
        BillingType.fixedPrice,
        status: JobStatus.completed,
      );
      final readiness = await JobBillingReadinessService().evaluate(job);
      expect(readiness.canInvoice, isFalse);
      expect(
        readiness.reasons.single.code,
        JobBillingReasonCode.missingApprovedQuote,
      );
    },
  );

  test('mixed fixed job also reports unbilled T&M variations', () async {
    final job = await _job(
      BillingType.fixedPrice,
      status: JobStatus.inProgress,
    );
    final variation = Task.forInsert(
      jobId: job.id,
      name: 'Variation',
      description: '',
      status: TaskStatus.approved,
      billingType: BillingType.timeAndMaterial,
    );
    await DaoTask().insert(variation);
    await DaoTimeEntry().insert(
      TimeEntry.forInsert(
        taskId: variation.id,
        startTime: DateTime(2025, 1, 1, 9),
        endTime: DateTime(2025, 1, 1, 10),
      ),
    );

    final readiness = await JobBillingReadinessService().evaluate(job);
    expect(
      readiness.reasons.map((reason) => reason.code),
      contains(JobBillingReasonCode.unbilledTimeAndMaterials),
    );
  });
}

Future<Job> _job(BillingType billingType, {required JobStatus status}) async {
  final job = Job.forInsert(
    customerId: 1,
    summary: 'Billing job',
    description: '',
    siteId: null,
    contactId: null,
    billingContactId: null,
    status: status,
    billingType: billingType,
    hourlyRate: MoneyEx.fromInt(10000),
    bookingFee: MoneyEx.zero,
  );
  await DaoJob().insert(job);
  return job;
}
