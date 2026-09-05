// test/job_status_fsm_test.dart
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/fsm/job_events.dart';
import 'package:hmb/fsm/job_states.dart';
import 'package:hmb/fsm/job_status_fsm.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  group('Job FSM hydration', () {
    test('no job state declares or offers a self-transition', () async {
      for (final status in JobStatus.values) {
        final job = await _insertJob(status);
        final machine = await buildJobMachine(job);

        await machine.traverseTree((definition, _) {
          for (final transition in definition.getTransitions()) {
            expect(
              transition.targetStates,
              isNot(contains(definition.stateType)),
              reason: '${definition.stateType} must not transition to itself',
            );
          }
        });

        final next = await nextStatusesOnly(machine: machine, job: job);
        expect(
          next,
          isNot(contains(status)),
          reason: 'Current status: $status',
        );
      }
    });

    test(
      'actions preserve different events with the same destination',
      () async {
        final job = await _insertJob(JobStatus.onHold);
        final machine = await buildJobMachine(job);
        final actions = await nextFromFsm(machine: machine, job: job);
        final resume = actions.where(
          (action) => action.to == JobStatus.inProgress,
        );

        expect(
          resume.map((action) => action.label),
          unorderedEquals(['Resume work', 'Confirm materials arrived']),
        );
        expect(
          resume.map((action) => action.event.runtimeType),
          unorderedEquals([ResumeJob, MaterialsArrived]),
        );
      },
    );

    test('work actions persist before reporting completion', () async {
      final job = await _insertJob(JobStatus.inProgress);
      final machine = await buildJobMachine(job);
      for (final eventType in [
        PauseJob,
        ResumeJob,
        CompleteJob,
        RaiseInvoice,
        ReopenJob,
      ]) {
        final actions = await nextFromFsm(machine: machine, job: job);
        final action = actions.singleWhere(
          (action) => action.event.runtimeType == eventType,
        );
        await action.fire(machine);
        expect((await DaoJob().getById(job.id))!.status, action.to);
        expect(job.status, action.to);
        expect(await currentState(machine), stateTypeFromStatus(action.to));
      }
    });

    test('completed work can be reopened with an explicit action', () async {
      final job = await _insertJob(JobStatus.completed);
      final machine = await buildJobMachine(job);
      final actions = await nextFromFsm(machine: machine, job: job);
      final reopen = actions.singleWhere((action) => action.event is ReopenJob);
      expect(reopen.label, 'Reopen job');
      await reopen.fire(machine);
      expect((await DaoJob().getById(job.id))!.status, JobStatus.inProgress);
    });

    test('reject and accept actions persist the FSM destination', () async {
      final job = await _insertJob(JobStatus.quoting);
      final machine = await buildJobMachine(job);
      for (final eventType in [RejectJob, ApproveQuote]) {
        final actions = await nextFromFsm(machine: machine, job: job);
        final action = actions.singleWhere(
          (action) => action.event.runtimeType == eventType,
        );
        await action.fire(machine);
        expect((await DaoJob().getById(job.id))!.status, action.to);
        expect(await currentState(machine), stateTypeFromStatus(action.to));
      }
    });

    test('starts in the persisted state without changing job.status', () async {
      final job = await _insertJob(JobStatus.inProgress);

      final machine = await buildJobMachine(job);

      // We hydrate directly into the persisted state; no transition fired.
      expect(await machine.isInState<InProgress>(), isTrue);
      expect(job.status, JobStatus.inProgress);
    });

    test(
      'next valid states from Quoting include AwaitingApproval and Rejected',
      () async {
        final job = await _insertJob(JobStatus.quoting);
        final machine = await buildJobMachine(job);

        final next = await nextStatusesOnly(machine: machine, job: job);

        // Direct transition + explicit reject transition on Quoting.
        expect(next, contains(JobStatus.awaitingApproval));
        expect(next, contains(JobStatus.rejected));

        // Obviously invalid from Quoting.
        expect(next, isNot(contains(JobStatus.completed)));
        expect(next, isNot(contains(JobStatus.toBeBilled)));
      },
    );

    test('Reject is available from every rejectable state', () async {
      final nonRejectable = {JobStatus.rejected, JobStatus.toBeBilled};
      for (final s in JobStatus.values.where(
        (s) => !nonRejectable.contains(s),
      )) {
        final job = await _insertJob(s);
        final machine = await buildJobMachine(job);

        final next = await nextStatusesOnly(machine: machine, job: job);
        expect(
          next,
          contains(JobStatus.rejected),
          reason: 'Reject must be available from $s',
        );
      }
    });

    test('marking job to be scheduled creates a schedule todo', () async {
      final job = await _insertJob(JobStatus.awaitingPayment);
      final machine = await buildJobMachine(job);
      machine.applyEvent(PaymentReceived(job));
      await machine.complete;

      final updatedJob = await DaoJob().getById(job.id);
      expect(updatedJob?.status, JobStatus.toBeScheduled);

      final openTodos = await DaoToDo().getOpenByJob(job.id);
      expect(
        openTodos.any(
          (todo) => todo.title.trim().toLowerCase() == 'schedule job',
        ),
        isTrue,
      );
    });

    test(
      'on hold offers to be scheduled and de-duplicates in progress',
      () async {
        final job = await _insertJob(JobStatus.onHold);
        final machine = await buildJobMachine(job);

        final next = await nextStatusesOnly(machine: machine, job: job);

        expect(next, contains(JobStatus.toBeScheduled));
        expect(
          next.where((status) => status == JobStatus.inProgress).length,
          1,
        );
      },
    );
  });
}

// Keep your helper consistent with your entity shape.
Future<Job> _insertJob(JobStatus status) async {
  final job = Job.forInsert(
    customerId: 1,
    summary: 'summary',
    description: 'description',
    siteId: 1,
    contactId: 1,
    status: status,
    hourlyRate: MoneyEx.zero,
    bookingFee: MoneyEx.zero,
    lastActive: true,
    billingContactId: 1,
  );
  final id = await DaoJob().insert(job);
  job.id = id;
  return job;
}
