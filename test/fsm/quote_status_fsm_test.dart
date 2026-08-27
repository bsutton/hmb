import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/fsm/lifecycle_event_dispatcher.dart';
import 'package:hmb/fsm/lifecycle_models.dart';
import 'package:hmb/fsm/lifecycle_rules.dart';
import 'package:hmb/fsm/quote_events.dart';
import 'package:hmb/fsm/quote_states.dart';
import 'package:hmb/fsm/quote_status_fsm.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

final _events = <Type, QuoteEvent Function(Quote quote)>{
  SendQuote: SendQuote.new,
  ApproveQuoteEvent: ApproveQuoteEvent.new,
  UnapproveQuote: UnapproveQuote.new,
  RejectQuoteEvent: RejectQuoteEvent.new,
  RejectQuoteAndJob: RejectQuoteAndJob.new,
  WithdrawQuote: WithdrawQuote.new,
  AmendQuote: AmendQuote.new,
  QuoteInvoiced: QuoteInvoiced.new,
};

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test('quote transition matrix rejects every unspecified event', () async {
    final expected = <QuoteState, Set<Type>>{
      QuoteState.reviewing: {
        SendQuote,
        RejectQuoteEvent,
        RejectQuoteAndJob,
        AmendQuote,
      },
      QuoteState.sent: {
        SendQuote,
        ApproveQuoteEvent,
        RejectQuoteEvent,
        RejectQuoteAndJob,
        WithdrawQuote,
        AmendQuote,
      },
      QuoteState.approved: {
        SendQuote,
        UnapproveQuote,
        RejectQuoteEvent,
        RejectQuoteAndJob,
        AmendQuote,
        QuoteInvoiced,
      },
      QuoteState.invoiced: {SendQuote, QuoteInvoiced},
      QuoteState.rejected: {AmendQuote},
      QuoteState.withdrawn: {AmendQuote},
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

  test('dispatcher persists every allowed quote edge and its audit', () async {
    for (final state in QuoteState.values) {
      for (final factory in _events.values) {
        final quote = await _insertQuote(state);
        final event = factory(quote);
        final target = targetForQuoteEvent(state, event);
        if (target == null) {
          continue;
        }
        final machine = await buildQuoteMachine(quote);
        machine.applyEvent(event);
        await machine.complete;
        expect(
          await currentQuoteState(machine),
          target,
          reason: 'fsm2: ${event.name} from ${state.name}',
        );
        final result = await LifecycleEventDispatcher().dispatchQuote(
          quote.id,
          factory,
          context: LifecycleContext(source: 'test.exhaustive'),
        );
        expect(
          result.entity.state,
          target,
          reason: '${event.name} from ${state.name}',
        );
        final audit = await DaoLifecycleTransition().getByJob(quote.jobId);
        expect(
          audit.where((row) => row.aggregateType == 'quote'),
          hasLength(1),
        );
      }
    }
  });

  test('every blocked quote edge leaves state and audit untouched', () async {
    for (final state in QuoteState.values) {
      for (final factory in _events.values) {
        final quote = await _insertQuote(state);
        if (targetForQuoteEvent(state, factory(quote)) != null) {
          continue;
        }
        await expectLater(
          LifecycleEventDispatcher().dispatchQuote(
            quote.id,
            factory,
            context: LifecycleContext(source: 'test.blocked'),
          ),
          throwsA(isA<LifecycleException>()),
          reason: '${factory(quote).name} from ${state.name}',
        );
        expect((await DaoQuote().getById(quote.id))?.state, state);
        expect(await DaoLifecycleTransition().getByJob(quote.jobId), isEmpty);
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
    'rejecting one of several quotes keeps the job awaiting approval',
    () async {
      final job = await _insertJob(JobStatus.awaitingApproval);
      final rejected = await _insertQuote(QuoteState.sent, job: job);
      final remaining = await _insertQuote(QuoteState.sent, job: job);

      await LifecycleEventDispatcher().dispatchQuote(
        rejected.id,
        RejectQuoteEvent.new,
        context: LifecycleContext(source: 'test.rejectOne'),
      );

      expect(
        (await DaoQuote().getById(rejected.id))?.state,
        QuoteState.rejected,
      );
      expect((await DaoQuote().getById(remaining.id))?.state, QuoteState.sent);
      expect(
        (await DaoJob().getById(job.id))?.status,
        JobStatus.awaitingApproval,
      );
    },
  );

  test('rejecting the last quote returns the job to quoting', () async {
    final job = await _insertJob(JobStatus.awaitingApproval);
    final quote = await _insertQuote(QuoteState.sent, job: job);

    await LifecycleEventDispatcher().dispatchQuote(
      quote.id,
      RejectQuoteEvent.new,
      context: LifecycleContext(source: 'test.rejectLast'),
    );

    expect((await DaoJob().getById(job.id))?.status, JobStatus.quoting);
  });

  test('withdrawing the last sent quote returns the job to quoting', () async {
    final job = await _insertJob(JobStatus.awaitingApproval);
    final quote = await _insertQuote(QuoteState.sent, job: job);

    await LifecycleEventDispatcher().dispatchQuote(
      quote.id,
      WithdrawQuote.new,
      context: LifecycleContext(source: 'test.withdrawLast'),
    );

    expect((await DaoJob().getById(job.id))?.status, JobStatus.quoting);
  });

  test('rejecting an approved quote reconciles other quote options', () async {
    final job = await _insertJob(JobStatus.awaitingPayment);
    final approved = await _insertQuote(QuoteState.approved, job: job);
    await _insertQuote(QuoteState.sent, job: job);

    await LifecycleEventDispatcher().dispatchQuote(
      approved.id,
      RejectQuoteEvent.new,
      context: LifecycleContext(source: 'test.rejectApproved'),
    );

    expect(
      (await DaoJob().getById(job.id))?.status,
      JobStatus.awaitingApproval,
    );
  });

  test('quote-only rejection works on completed jobs', () async {
    final job = await _insertJob(JobStatus.completed);
    final quote = await _insertQuote(QuoteState.sent, job: job);

    await LifecycleEventDispatcher().dispatchQuote(
      quote.id,
      RejectQuoteEvent.new,
      context: LifecycleContext(source: 'test.completedQuote'),
    );

    expect((await DaoQuote().getById(quote.id))?.state, QuoteState.rejected);
    expect((await DaoJob().getById(job.id))?.status, JobStatus.completed);
  });

  test(
    'quote-and-job rejection rejects every active quote atomically',
    () async {
      final job = await _insertJob(JobStatus.awaitingApproval);
      final selected = await _insertQuote(QuoteState.sent, job: job);
      final alternative = await _insertQuote(QuoteState.reviewing, job: job);

      await LifecycleEventDispatcher().dispatchQuote(
        selected.id,
        RejectQuoteAndJob.new,
        context: LifecycleContext(source: 'test.rejectJob'),
      );

      expect((await DaoJob().getById(job.id))?.status, JobStatus.rejected);
      expect(
        (await DaoQuote().getById(selected.id))?.state,
        QuoteState.rejected,
      );
      expect(
        (await DaoQuote().getById(alternative.id))?.state,
        QuoteState.rejected,
      );
    },
  );

  test(
    'quote-and-job rejection is blocked without changing completed work',
    () async {
      final job = await _insertJob(JobStatus.completed);
      final quote = await _insertQuote(QuoteState.sent, job: job);

      await expectLater(
        LifecycleEventDispatcher().dispatchQuote(
          quote.id,
          RejectQuoteAndJob.new,
          context: LifecycleContext(source: 'test.invalidRejectJob'),
        ),
        throwsA(isA<LifecycleException>()),
      );

      expect((await DaoQuote().getById(quote.id))?.state, QuoteState.sent);
      expect((await DaoJob().getById(job.id))?.status, JobStatus.completed);
      expect(await DaoLifecycleTransition().getByJob(job.id), isEmpty);
    },
  );

  test(
    'invoiced milestones block destructive quote events atomically',
    () async {
      final job = await _insertJob(JobStatus.awaitingPayment);
      final quote = await _insertQuote(QuoteState.approved, job: job);
      final milestone = Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: 1,
        paymentAmount: MoneyEx.dollars(100),
        paymentPercentage: Percentage.fromInt(100),
        milestoneDescription: 'Already invoiced',
        invoiceId: 123,
      );
      await DaoMilestone().insert(milestone);

      for (final factory in <QuoteEvent Function(Quote)>[
        UnapproveQuote.new,
        RejectQuoteEvent.new,
        RejectQuoteAndJob.new,
        AmendQuote.new,
      ]) {
        await expectLater(
          LifecycleEventDispatcher().dispatchQuote(
            quote.id,
            factory,
            context: LifecycleContext(source: 'test.invoicedGuard'),
          ),
          throwsA(isA<LifecycleException>()),
        );
        expect(
          (await DaoQuote().getById(quote.id))?.state,
          QuoteState.approved,
        );
        expect((await DaoMilestone().getById(milestone.id))?.voided, isFalse);
        expect(
          (await DaoJob().getById(job.id))?.status,
          JobStatus.awaitingPayment,
        );
        expect(await DaoLifecycleTransition().getByJob(job.id), isEmpty);
      }
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
