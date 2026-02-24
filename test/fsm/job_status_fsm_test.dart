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
      await Future<void>.delayed(const Duration(milliseconds: 100));

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
