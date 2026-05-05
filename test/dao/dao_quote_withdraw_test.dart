import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
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
    final activeJob = job.copyWith(status: JobStatus.inProgress);
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

    final updatedJob = await DaoJob().getById(job.id);
    expect(updatedJob?.status, JobStatus.inProgress);
  });
}
