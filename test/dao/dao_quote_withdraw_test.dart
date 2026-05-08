import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('withdrawQuote marks quote as withdrawn', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
      bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
    );

    final quoteId = await DaoQuote().insert(
      Quote.forInsert(
        jobId: job.id,
        summary: 'Withdraw test quote',
        description: 'Quote to test withdrawn state',
        totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
        state: QuoteState.sent,
      ),
    );

    await DaoQuote().withdrawQuote(quoteId);

    final quote = await DaoQuote().getById(quoteId);
    expect(quote?.state, QuoteState.withdrawn);
  });

  test('amendQuote creates replacement quote and rejects original', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
    );
    final contact = (await DaoContact().getById(job.billingContactId))!;

    final task = Task.forInsert(
      jobId: job.id,
      name: 'Amended task',
      description: '',
      status: TaskStatus.awaitingApproval,
    );
    await DaoTask().insert(task);

    await DaoTaskItem().insert(
      TaskItem.forInsert(
        taskId: task.id,
        description: 'Labour item',
        purpose: '',
        itemType: TaskItemType.labour,
        estimatedLabourHours: Fixed.fromNum(2, decimalDigits: 3),
        estimatedLabourCost: Money.fromInt(5000, isoCode: 'AUD'),
        chargeMode: ChargeMode.userDefined,
        totalLineCharge: Money.fromInt(12000, isoCode: 'AUD'),
        margin: Percentage.zero,
        measurementType: MeasurementType.length,
        dimension1: Fixed.zero,
        dimension2: Fixed.zero,
        dimension3: Fixed.zero,
        units: Units.m,
        url: '',
        labourEntryMode: LabourEntryMode.hours,
      ),
    );

    final originalId = await DaoQuote().insert(
      Quote.forInsert(
        jobId: job.id,
        summary: 'Original quote',
        description: 'Quote to amend',
        totalAmount: Money.fromInt(10000, isoCode: 'AUD'),
        state: QuoteState.sent,
      ),
    );
    final original = (await DaoQuote().getById(originalId))!;

    final amended = await DaoQuote().amendQuote(
      original,
      InvoiceOptions(
        selectedTaskIds: [task.id],
        billBookingFee: false,
        groupByTask: true,
        contact: contact,
      ),
    );

    final reloadedOriginal = await DaoQuote().getById(original.id);
    final amendedGroups = await DaoQuoteLineGroup().getByQuoteId(amended.id);

    expect(reloadedOriginal?.state, QuoteState.rejected);
    expect(amended.id, isNot(original.id));
    expect(amended.state, QuoteState.reviewing);
    expect(amendedGroups.single.taskId, task.id);
  });

  test('markQuoteSent moves prospecting job to awaiting approval', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
    );
    expect(job.status, JobStatus.prospecting);

    final quoteId = await DaoQuote().insert(
      Quote.forInsert(
        jobId: job.id,
        summary: 'Prospecting job quote',
        description: 'Quote to test job status update',
        totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
      ),
    );

    await DaoQuote().markQuoteSent(quoteId);

    final quote = await DaoQuote().getById(quoteId);
    expect(quote?.state, QuoteState.sent);
    expect(quote?.dateSent, isNotNull);

    final updatedJob = await DaoJob().getById(job.id);
    expect(updatedJob?.status, JobStatus.awaitingApproval);
  });

  test('markQuoteSent leaves active jobs unchanged', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
    );
    final activeJob = job.copyWith(status: JobStatus.scheduled);
    await DaoJob().update(activeJob);

    final quoteId = await DaoQuote().insert(
      Quote.forInsert(
        jobId: job.id,
        summary: 'Active job quote',
        description: 'Quote to test guarded job status update',
        totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
      ),
    );

    await DaoQuote().markQuoteSent(quoteId);

    final quote = await DaoQuote().getById(quoteId);
    expect(quote?.state, QuoteState.sent);
    expect(quote?.dateSent, isNotNull);

    final updatedJob = await DaoJob().getById(job.id);
    expect(updatedJob?.status, JobStatus.scheduled);
  });
}
