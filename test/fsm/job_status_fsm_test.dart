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
          QuoteNeedsRevision,
          ProceedToScheduling,
          StartWork,
          PauseJob,
          RejectJob,
        },
        JobStatus.awaitingPayment: {
          PaymentReceived,
          ProceedToScheduling,
          QuoteUnapproved,
          QuoteNeedsRevision,
          StartWork,
          PauseJob,
          RejectJob,
        },
        JobStatus.toBeScheduled: {ScheduleJob, StartWork, PauseJob, RejectJob},
        JobStatus.scheduled: {
          ScheduleRemoved,
          StartWork,
          WaitForMaterials,
          PauseJob,
          CompleteJob,
          RejectJob,
        },
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
          CompleteJob,
          RejectJob,
        },
        JobStatus.awaitingMaterials: {
          MaterialsArrived,
          ResumeJob,
          PauseJob,
          ProceedToScheduling,
          CompleteJob,
          RejectJob,
        },
        JobStatus.completed: {ReopenWork, ReopenForScheduling},
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

    test('every allowed edge is implemented by fsm2 and dispatcher', () async {
      for (final status in JobStatus.values) {
        for (final factory in eventFactory.values) {
          final job = await _insertJob(
            status,
            resumeStatus: _resumeStatusFor(status),
          );
          final event = factory(job);
          final target = targetForJobEvent(status, event);
          if (target == null) {
            continue;
          }

          final machine = await buildJobMachine(job);
          machine.applyEvent(event);
          await machine.complete;
          expect(
            stateFromType(await currentState(machine)).status,
            target,
            reason: 'fsm2: ${event.name} from ${status.name}',
          );

          final result = await LifecycleEventDispatcher().dispatchJob(
            job.id,
            factory,
            context: LifecycleContext(source: 'test.exhaustive'),
          );
          expect(
            result.entity.status,
            target,
            reason: 'dispatcher: ${event.name} from ${status.name}',
          );
          final audit = await DaoLifecycleTransition().getByJob(job.id);
          expect(audit, hasLength(1));
          expect(audit.single.event, event.name);
        }
      }
    });

    test('every blocked edge leaves state and audit untouched', () async {
      for (final status in JobStatus.values) {
        for (final factory in eventFactory.values) {
          final job = await _insertJob(
            status,
            resumeStatus: _resumeStatusFor(status),
          );
          if (targetForJobEvent(status, factory(job)) != null) {
            continue;
          }
          await expectLater(
            LifecycleEventDispatcher().dispatchJob(
              job.id,
              factory,
              context: LifecycleContext(source: 'test.blocked'),
            ),
            throwsA(isA<LifecycleException>()),
            reason: '${factory(job).name} from ${status.name}',
          );
          expect((await DaoJob().getById(job.id))?.status, status);
          expect(await DaoLifecycleTransition().getByJob(job.id), isEmpty);
        }
      }
    });

    test('every persisted job state exposes a user recovery action', () async {
      for (final status in JobStatus.values) {
        final job = await _insertJob(
          status,
          resumeStatus: _resumeStatusFor(status),
        );
        final actions = await nextFromFsm(
          machine: await buildJobMachine(job),
          job: job,
        );
        expect(actions, isNotEmpty, reason: '${status.name} has no UI exit');
      }
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

    test('hold and resume preserve every source workflow stage', () async {
      final sources = [
        JobStatus.prospecting,
        JobStatus.quoting,
        JobStatus.awaitingApproval,
        JobStatus.awaitingPayment,
        JobStatus.toBeScheduled,
        JobStatus.scheduled,
        JobStatus.inProgress,
      ];
      for (final source in sources) {
        final job = await _insertJob(source);
        final held = await LifecycleEventDispatcher().dispatchJob(
          job.id,
          PauseJob.new,
          context: LifecycleContext(source: 'test.hold'),
        );
        expect(held.entity.status, JobStatus.onHold);
        expect(held.entity.resumeStatus, source);
        final resumeAction = (await nextFromFsm(
          machine: await buildJobMachine(held.entity),
          job: held.entity,
        )).firstWhere((next) => next.action.eventType == ResumeJob);
        expect(resumeAction.to, source);

        final resumed = await LifecycleEventDispatcher().dispatchJob(
          job.id,
          ResumeJob.new,
          context: LifecycleContext(source: 'test.resume'),
        );
        expect(resumed.entity.status, source, reason: source.name);
        expect(resumed.entity.resumeStatus, isNull);
      }
    });

    test('materials wait also restores the workflow stage', () async {
      final job = await _insertJob(JobStatus.scheduled);
      final waiting = await LifecycleEventDispatcher().dispatchJob(
        job.id,
        WaitForMaterials.new,
        context: LifecycleContext(source: 'test.materials'),
      );
      expect(waiting.entity.resumeStatus, JobStatus.scheduled);

      final resumed = await LifecycleEventDispatcher().dispatchJob(
        job.id,
        MaterialsArrived.new,
        context: LifecycleContext(source: 'test.materials'),
      );
      expect(resumed.entity.status, JobStatus.scheduled);
      expect(resumed.entity.resumeStatus, isNull);
    });

    test(
      'exception completion and scheduling reopen avoid false work events',
      () async {
        for (final status in [
          JobStatus.scheduled,
          JobStatus.onHold,
          JobStatus.awaitingMaterials,
        ]) {
          final job = await _insertJob(
            status,
            resumeStatus: _resumeStatusFor(status),
          );
          final completed = await LifecycleEventDispatcher().dispatchJob(
            job.id,
            CompleteJob.new,
            context: LifecycleContext(source: 'test.exceptionComplete'),
          );
          expect(completed.entity.status, JobStatus.completed);
        }

        final completed = await _insertJob(JobStatus.completed);
        final reopened = await LifecycleEventDispatcher().dispatchJob(
          completed.id,
          ReopenForScheduling.new,
          context: LifecycleContext(source: 'test.reopen'),
        );
        expect(reopened.entity.status, JobStatus.toBeScheduled);
        expect(
          (await DaoToDo().getOpenByJob(
            completed.id,
          )).map((todo) => todo.title),
          contains('Schedule job'),
        );
      },
    );

    test(
      'schedule activity and lifecycle transitions commit together',
      () async {
        final job = await _insertJob(JobStatus.awaitingPayment);
        final activity = JobActivity.forInsert(
          jobId: job.id,
          start: DateTime(2026, 9, 1, 9),
          end: DateTime(2026, 9, 1, 11),
        );

        await LifecycleEventDispatcher().scheduleActivity(
          activity,
          context: LifecycleContext(source: 'test.schedule'),
        );

        expect((await DaoJob().getById(job.id))?.status, JobStatus.scheduled);
        expect(await DaoJobActivity().getByJob(job.id), hasLength(1));
        final audit = await DaoLifecycleTransition().getByJob(job.id);
        expect(
          audit.map((row) => row.event),
          containsAll(['ProceedToScheduling', 'ScheduleCreated']),
        );
      },
    );

    test('scheduling advances every pre-work stage coherently', () async {
      for (final status in [
        JobStatus.prospecting,
        JobStatus.quoting,
        JobStatus.awaitingApproval,
        JobStatus.awaitingPayment,
        JobStatus.toBeScheduled,
        JobStatus.onHold,
        JobStatus.awaitingMaterials,
      ]) {
        final job = await _insertJob(
          status,
          resumeStatus: _resumeStatusFor(status),
        );
        final activity = JobActivity.forInsert(
          jobId: job.id,
          start: DateTime(2026, 9, 1, 9),
          end: DateTime(2026, 9, 1, 11),
        );

        await LifecycleEventDispatcher().scheduleActivity(
          activity,
          context: LifecycleContext(source: 'test.schedule.$status'),
        );

        expect(
          (await DaoJob().getById(job.id))?.status,
          JobStatus.scheduled,
          reason: status.name,
        );
      }
    });

    test('scheduling completed work reopens it for scheduling', () async {
      final job = await _insertJob(JobStatus.completed);
      final activity = JobActivity.forInsert(
        jobId: job.id,
        start: DateTime(2026, 9, 1, 9),
        end: DateTime(2026, 9, 1, 11),
      );

      await LifecycleEventDispatcher().scheduleActivity(
        activity,
        context: LifecycleContext(source: 'test.scheduleCompleted'),
      );

      expect((await DaoJob().getById(job.id))?.status, JobStatus.scheduled);
      expect(
        (await DaoLifecycleTransition().getByJob(
          job.id,
        )).map((row) => row.event),
        containsAll(['ReopenForScheduling', 'ScheduleCreated']),
      );
    });

    test('scheduling rejected work rolls back the activity insert', () async {
      final job = await _insertJob(JobStatus.rejected);
      final before = await DaoJobActivity().count();
      final activity = JobActivity.forInsert(
        jobId: job.id,
        start: DateTime(2026, 9, 1, 9),
        end: DateTime(2026, 9, 1, 11),
      );

      await expectLater(
        LifecycleEventDispatcher().scheduleActivity(
          activity,
          context: LifecycleContext(source: 'test.scheduleRejected'),
        ),
        throwsA(isA<LifecycleException>()),
      );

      expect(await DaoJobActivity().count(), before);
      expect((await DaoJob().getById(job.id))?.status, JobStatus.rejected);
    });

    test('missing schedule job rolls back the activity insert', () async {
      final before = await DaoJobActivity().count();
      final activity = JobActivity.forInsert(
        jobId: 999999,
        start: DateTime(2026, 9, 1, 9),
        end: DateTime(2026, 9, 1, 11),
      );

      await expectLater(
        LifecycleEventDispatcher().scheduleActivity(
          activity,
          context: LifecycleContext(source: 'test.scheduleMissing'),
        ),
        throwsA(anything),
      );
      expect(await DaoJobActivity().count(), before);
    });

    test(
      'deleting the last activity returns scheduled work to the queue',
      () async {
        final job = await _insertJob(JobStatus.toBeScheduled);
        final activity = JobActivity.forInsert(
          jobId: job.id,
          start: DateTime(2026, 9, 1, 9),
          end: DateTime(2026, 9, 1, 11),
        );
        await LifecycleEventDispatcher().scheduleActivity(
          activity,
          context: LifecycleContext(source: 'test.schedule'),
        );

        await LifecycleEventDispatcher().deleteScheduledActivity(
          activity.id,
          context: LifecycleContext(source: 'test.unschedule'),
        );

        expect(
          (await DaoJob().getById(job.id))?.status,
          JobStatus.toBeScheduled,
        );
        expect(await DaoJobActivity().getByJob(job.id), isEmpty);
        expect(
          (await DaoLifecycleTransition().getByJob(job.id)).first.event,
          'ScheduleRemoved',
        );
      },
    );

    test('moving the last activity reconciles both jobs atomically', () async {
      final originalJob = await _insertJob(JobStatus.toBeScheduled);
      final newJob = await _insertJob(JobStatus.toBeScheduled);
      final activity = JobActivity.forInsert(
        jobId: originalJob.id,
        start: DateTime(2026, 9, 1, 9),
        end: DateTime(2026, 9, 1, 11),
      );
      await LifecycleEventDispatcher().scheduleActivity(
        activity,
        context: LifecycleContext(source: 'test.schedule'),
      );

      await LifecycleEventDispatcher().updateScheduledActivity(
        activity.copyWith(jobId: newJob.id),
        context: LifecycleContext(source: 'test.moveSchedule'),
      );

      expect(
        (await DaoJob().getById(originalJob.id))?.status,
        JobStatus.toBeScheduled,
      );
      expect((await DaoJob().getById(newJob.id))?.status, JobStatus.scheduled);
      expect(await DaoJobActivity().getByJob(originalJob.id), isEmpty);
      expect(await DaoJobActivity().getByJob(newJob.id), hasLength(1));
    });

    test(
      'updating a missing activity does not change the target job',
      () async {
        final job = await _insertJob(JobStatus.toBeScheduled);
        final missing = JobActivity.forInsert(
          jobId: job.id,
          start: DateTime(2026, 9, 1, 9),
          end: DateTime(2026, 9, 1, 11),
        )..id = 999999;

        await expectLater(
          LifecycleEventDispatcher().updateScheduledActivity(
            missing,
            context: LifecycleContext(source: 'test.updateMissingSchedule'),
          ),
          throwsA(isA<LifecycleException>()),
        );

        expect(
          (await DaoJob().getById(job.id))?.status,
          JobStatus.toBeScheduled,
        );
        expect(await DaoJobActivity().getByJob(job.id), isEmpty);
      },
    );

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

JobStatus? _resumeStatusFor(JobStatus status) => switch (status) {
  JobStatus.onHold || JobStatus.awaitingMaterials => JobStatus.awaitingApproval,
  _ => null,
};

Future<Job> _insertJob(JobStatus status, {JobStatus? resumeStatus}) async {
  final job = Job.forInsert(
    customerId: 1,
    summary: 'summary',
    description: 'description',
    siteId: 1,
    contactId: 1,
    status: status,
    resumeStatus: resumeStatus,
    hourlyRate: MoneyEx.zero,
    bookingFee: MoneyEx.zero,
    lastActive: true,
    billingContactId: 1,
  );
  await DaoJob().insert(job);
  return job;
}
