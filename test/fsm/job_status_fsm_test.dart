import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/fsm/job_events.dart';
import 'package:hmb/fsm/job_states.dart';
import 'package:hmb/fsm/job_status_fsm.dart';
import 'package:hmb/fsm/lifecycle_event_dispatcher.dart';
import 'package:hmb/fsm/lifecycle_models.dart';
import 'package:hmb/fsm/lifecycle_rules.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  group('Job lifecycle rules', () {
    test('hydrates every persisted state without writing it', () async {
      for (final status in JobStatus.values) {
        final job = await _insertJob(status);
        final machine = await buildJobMachine(job);
        expect(await currentState(machine), stateTypeFromStatus(status));
        expect((await DaoJob().getById(job.id))?.status, status);
      }
    });

    test('allowed transitions exactly match the domain matrix', () async {
      final expected = <JobStatus, Set<Type>>{
        JobStatus.prospecting: {
          StartQuoting,
          SubmitQuote,
          ProceedToScheduling,
          StartWork,
          PauseJob,
          RejectJob,
        },
        JobStatus.quoting: {
          SubmitQuote,
          ProceedToScheduling,
          StartWork,
          PauseJob,
          RejectJob,
        },
        JobStatus.awaitingApproval: {
          ApproveQuote,
          ProceedToScheduling,
          StartWork,
          PauseJob,
          RejectJob,
        },
        JobStatus.awaitingPayment: {
          PaymentReceived,
          ProceedToScheduling,
          QuoteUnapproved,
          StartWork,
          PauseJob,
          RejectJob,
        },
        JobStatus.toBeScheduled: {ScheduleJob, StartWork, PauseJob, RejectJob},
        JobStatus.scheduled: {StartWork, WaitForMaterials, PauseJob, RejectJob},
        JobStatus.inProgress: {
          StartWork,
          WaitForMaterials,
          PauseJob,
          CompleteJob,
          RejectJob,
        },
        JobStatus.onHold: {
          ResumeJob,
          WaitForMaterials,
          ProceedToScheduling,
          RejectJob,
        },
        JobStatus.awaitingMaterials: {
          MaterialsArrived,
          ResumeJob,
          PauseJob,
          RejectJob,
        },
        JobStatus.completed: {ReopenWork},
        JobStatus.rejected: {RestoreJob},
      };

      for (final status in JobStatus.values) {
        final job = await _insertJob(status);
        for (final entry in eventFactory.entries) {
          final allowed = targetForJobEvent(status, entry.value(job)) != null;
          expect(
            allowed,
            expected[status]!.contains(entry.key),
            reason: '${entry.key} from ${status.name}',
          );
        }
      }
    });

    test('every job state is reachable from prospecting', () async {
      final reached = <JobStatus>{JobStatus.prospecting};
      var changed = true;
      while (changed) {
        changed = false;
        for (final from in reached.toList()) {
          final job = await _insertJob(from);
          for (final factory in eventFactory.values) {
            final target = targetForJobEvent(from, factory(job));
            if (target != null && reached.add(target)) {
              changed = true;
            }
          }
        }
      }
      expect(reached, JobStatus.values.toSet());
    });
  });

  group('Job lifecycle dispatcher', () {
    test('persists transition, entry action and audit atomically', () async {
      final job = await _insertJob(JobStatus.awaitingPayment);
      final result = await LifecycleEventDispatcher().dispatchJob(
        job.id,
        PaymentReceived.new,
        context: LifecycleContext(source: 'test', reason: 'Deposit cleared'),
      );

      expect(result.entity.status, JobStatus.toBeScheduled);
      expect(result.changed, isTrue);
      final todos = await DaoToDo().getOpenByJob(job.id);
      expect(todos.map((todo) => todo.title), contains('Schedule job'));
      final audit = await DaoLifecycleTransition().getByJob(job.id);
      expect(audit, hasLength(1));
      expect(audit.single.event, 'PaymentReceived');
      expect(audit.single.reason, 'Deposit cleared');
    });

    test('invalid event makes no state or audit write', () async {
      final job = await _insertJob(JobStatus.completed);

      await expectLater(
        LifecycleEventDispatcher().dispatchJob(
          job.id,
          RejectJob.new,
          context: LifecycleContext(source: 'test'),
        ),
        throwsA(isA<LifecycleException>()),
      );

      expect((await DaoJob().getById(job.id))?.status, JobStatus.completed);
      expect(await DaoLifecycleTransition().getByJob(job.id), isEmpty);
    });

    test('DAO rejects direct lifecycle state writes', () async {
      final job = await _insertJob(JobStatus.prospecting);
      await expectLater(
        DaoJob().update(job.copyWith(status: JobStatus.inProgress)),
        throwsA(isA<LifecycleException>()),
      );
      expect((await DaoJob().getById(job.id))?.status, JobStatus.prospecting);
    });

    test('navigation records recency without starting work', () async {
      final job = await _insertJob(JobStatus.prospecting);
      final updated = await markJobActive(job.id);
      expect(updated.status, JobStatus.prospecting);
      expect(await DaoLifecycleTransition().getByJob(job.id), isEmpty);
    });

    test('picker keeps distinct actions with the same destination', () async {
      final job = await _insertJob(JobStatus.awaitingPayment);
      final machine = await buildJobMachine(job);
      final actions = await nextFromFsm(machine: machine, job: job);
      final scheduling = actions
          .where((action) => action.to == JobStatus.toBeScheduled)
          .toList();
      expect(scheduling, hasLength(2));
      expect(
        scheduling.map((action) => action.action.label),
        containsAll(['Payment received', 'Proceed to scheduling']),
      );
    });

    test(
      'start-work payload commits timer, task, job and audit together',
      () async {
        final job = await _insertJob(JobStatus.scheduled);
        final task = Task.forInsert(
          jobId: job.id,
          name: 'Work',
          description: '',
          status: TaskStatus.approved,
        );
        await DaoTask().insert(task);
        final entry = TimeEntry.forInsert(
          taskId: task.id,
          startTime: DateTime(2025, 1, 1, 9),
        );

        await LifecycleEventDispatcher().dispatchJob(
          job.id,
          (job) => StartWork(job, task: task, timeEntry: entry),
          context: LifecycleContext(source: 'test.timer'),
        );

        expect((await DaoJob().getById(job.id))?.status, JobStatus.inProgress);
        expect(
          (await DaoTask().getById(task.id))?.status,
          TaskStatus.inProgress,
        );
        expect(await DaoTimeEntry().getById(entry.id), isNotNull);
        expect(await DaoLifecycleTransition().getByJob(job.id), hasLength(1));
      },
    );

    test('invalid start-work payload rolls back every write', () async {
      final job = await _insertJob(JobStatus.completed);
      final task = Task.forInsert(
        jobId: job.id,
        name: 'Work',
        description: '',
        status: TaskStatus.approved,
      );
      await DaoTask().insert(task);
      final entry = TimeEntry.forInsert(
        taskId: task.id,
        startTime: DateTime(2025, 1, 1, 9),
      );

      await expectLater(
        LifecycleEventDispatcher().dispatchJob(
          job.id,
          (job) => StartWork(job, task: task, timeEntry: entry),
          context: LifecycleContext(source: 'test.timer'),
        ),
        throwsA(isA<LifecycleException>()),
      );

      expect((await DaoJob().getById(job.id))?.status, JobStatus.completed);
      expect((await DaoTask().getById(task.id))?.status, TaskStatus.approved);
      expect(await DaoTimeEntry().getByTask(task.id), isEmpty);
      expect(await DaoLifecycleTransition().getByJob(job.id), isEmpty);
    });
  });
}

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
  await DaoJob().insert(job);
  return job;
}
