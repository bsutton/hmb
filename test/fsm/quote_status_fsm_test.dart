import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/fsm/lifecycle_event_dispatcher.dart';
import 'package:hmb/fsm/lifecycle_models.dart';
import 'package:hmb/fsm/lifecycle_rules.dart';
import 'package:hmb/fsm/quote_events.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

final _events = <Type, QuoteEvent Function(Quote quote)>{
  SendQuote: SendQuote.new,
  ApproveQuoteEvent: ApproveQuoteEvent.new,
  UnapproveQuote: UnapproveQuote.new,
  RejectQuoteEvent: RejectQuoteEvent.new,
  WithdrawQuote: WithdrawQuote.new,
  AmendQuote: AmendQuote.new,
  QuoteInvoiced: QuoteInvoiced.new,
};

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test('quote transition matrix rejects every unspecified event', () async {
    final expected = <QuoteState, Set<Type>>{
      QuoteState.reviewing: {SendQuote, RejectQuoteEvent, AmendQuote},
      QuoteState.sent: {
        SendQuote,
        ApproveQuoteEvent,
        RejectQuoteEvent,
        WithdrawQuote,
        AmendQuote,
      },
      QuoteState.approved: {
        SendQuote,
        UnapproveQuote,
        RejectQuoteEvent,
        AmendQuote,
        QuoteInvoiced,
      },
      QuoteState.invoiced: {SendQuote, QuoteInvoiced},
      QuoteState.rejected: {},
      QuoteState.withdrawn: {},
    };

    for (final state in QuoteState.values) {
      final quote = await _insertQuote(state);
      for (final entry in _events.entries) {
        expect(
          targetForQuoteEvent(state, entry.value(quote)) != null,
          expected[state]!.contains(entry.key),
          reason: '${entry.key} from ${state.name}',
        );
      }
    }
  });

  test('send and approval advance the job and audit both aggregates', () async {
    final job = await _insertJob(JobStatus.quoting);
    final quote = await _insertQuote(QuoteState.reviewing, job: job);
    final dispatcher = LifecycleEventDispatcher();

    await dispatcher.dispatchQuote(
      quote.id,
      SendQuote.new,
      context: LifecycleContext(source: 'test.send'),
    );
    expect(
      (await DaoJob().getById(job.id))?.status,
      JobStatus.awaitingApproval,
    );

    await dispatcher.dispatchQuote(
      quote.id,
      ApproveQuoteEvent.new,
      context: LifecycleContext(source: 'test.approve'),
    );
    expect((await DaoJob().getById(job.id))?.status, JobStatus.awaitingPayment);
    expect((await DaoQuote().getById(quote.id))?.state, QuoteState.approved);

    final audit = await DaoLifecycleTransition().getByJob(job.id);
    expect(audit.where((row) => row.aggregateType == 'quote'), hasLength(2));
    expect(audit.where((row) => row.aggregateType == 'job'), hasLength(2));
  });

  test(
    'resending an approved quote preserves approval and active job state',
    () async {
      final job = await _insertJob(JobStatus.inProgress);
      final quote = await _insertQuote(QuoteState.approved, job: job);

      final result = await LifecycleEventDispatcher().dispatchQuote(
        quote.id,
        SendQuote.new,
        context: LifecycleContext(source: 'test.resend'),
      );

      expect(result.entity.state, QuoteState.approved);
      expect(result.changed, isFalse);
      expect((await DaoJob().getById(job.id))?.status, JobStatus.inProgress);
    },
  );

  test(
    'unapproval does not regress a job with another approved quote',
    () async {
      final job = await _insertJob(JobStatus.awaitingPayment);
      final quote = await _insertQuote(QuoteState.approved, job: job);
      await _insertQuote(QuoteState.approved, job: job);

      await LifecycleEventDispatcher().dispatchQuote(
        quote.id,
        UnapproveQuote.new,
        context: LifecycleContext(source: 'test.unapprove'),
      );

      expect(
        (await DaoJob().getById(job.id))?.status,
        JobStatus.awaitingPayment,
      );
    },
  );

  test('invalid quote event leaves state and audit untouched', () async {
    final quote = await _insertQuote(QuoteState.withdrawn);
    await expectLater(
      LifecycleEventDispatcher().dispatchQuote(
        quote.id,
        ApproveQuoteEvent.new,
        context: LifecycleContext(source: 'test.invalid'),
      ),
      throwsA(isA<LifecycleException>()),
    );
    expect((await DaoQuote().getById(quote.id))?.state, QuoteState.withdrawn);
    expect(await DaoLifecycleTransition().getByJob(quote.jobId), isEmpty);
  });

  test('DAO rejects direct quote state writes', () async {
    final quote = await _insertQuote(QuoteState.reviewing);
    await expectLater(
      DaoQuote().update(quote.copyWith(state: QuoteState.approved)),
      throwsA(isA<LifecycleException>()),
    );
    expect((await DaoQuote().getById(quote.id))?.state, QuoteState.reviewing);
  });
}

Future<Job> _insertJob(JobStatus status) async {
  final job = Job.forInsert(
    customerId: 1,
    summary: 'Quote job',
    description: 'description',
    siteId: 1,
    contactId: 1,
    billingContactId: 1,
    status: status,
    hourlyRate: MoneyEx.zero,
    bookingFee: MoneyEx.zero,
  );
  await DaoJob().insert(job);
  return job;
}

Future<Quote> _insertQuote(QuoteState state, {Job? job}) async {
  final owner = job ?? await _insertJob(JobStatus.prospecting);
  final quote = Quote.forInsert(
    jobId: owner.id,
    summary: 'Quote',
    description: 'description',
    totalAmount: MoneyEx.zero,
    state: state,
  );
  await DaoQuote().insert(quote);
  return quote;
}
