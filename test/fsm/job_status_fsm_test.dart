// test/job_status_fsm_test.dart
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/fsm/job_states.dart';
import 'package:hmb/fsm/job_status_fsm.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

void main() {
  group('Job FSM hydration', () {
    test('starts in the persisted state without changing job.status', () async {
      final job = _getJob()..status = JobStatus.inProgress;

      final machine = await buildJobMachine(job);

      // We hydrate directly into the persisted state; no transition fired.
      expect(await machine.isInState<InProgress>(), isTrue);
      expect(job.status, JobStatus.inProgress);
    });

    test(
      'next valid states from Quoting include AwaitingApproval and Rejected',
      () async {
        final job = _getJob()..status = JobStatus.quoting;
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

    test('Reject is available from every non-rejected state', () async {
      for (final s in JobStatus.values.where((s) => s != JobStatus.rejected)) {
        final job = _getJob()..status = s;
        final machine = await buildJobMachine(job);

        final next = await nextStatusesOnly(machine: machine, job: job);
        expect(
          next,
          contains(JobStatus.rejected),
          reason: 'Reject must be available from $s',
        );
      }
    });
  });
}

// Keep your helper consistent with your entity shape.
Job _getJob() => Job(
  id: 1,
  customerId: 1,
  summary: 'summary',
  description: 'description',
  assumption: '',
  siteId: 1,
  contactId: 1,
  status: JobStatus.awaitingApproval,
  hourlyRate: MoneyEx.zero,
  bookingFee: MoneyEx.zero,
  lastActive: true,
  createdDate: DateTime.now(),
  modifiedDate: DateTime.now(),
  billingContactId: 1,
);
