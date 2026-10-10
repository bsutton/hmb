import 'dart:async';
import 'dart:io';

import 'package:hmb/dao/cancelled_schedule.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/fsm/job_events.dart';
import 'package:hmb/fsm/lifecycle_event_dispatcher.dart';
import 'package:hmb/fsm/lifecycle_models.dart';
import 'package:hmb/fsm/quote_events.dart';
import 'package:hmb/integrations/google_calendar/cancelled_schedule_cleanup.dart';
import 'package:hmb/integrations/google_calendar/google_calendar_sync.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  Future<Job> job() async {
    final value = Job.forInsert(
      customerId: 1,
      summary: 'Cancellation fixture',
      description: '',
      siteId: 1,
      contactId: 1,
      billingContactId: 1,
      status: JobStatus.scheduled,
      hourlyRate: MoneyEx.zero,
      bookingFee: MoneyEx.zero,
    );
    await DaoJob().insert(value);
    return value;
  }

  Future<JobActivity> booking(Job job) async {
    final activity = JobActivity.forInsert(
      jobId: job.id,
      start: DateTime(2030, 1, 1, 9),
      end: DateTime(2030, 1, 1, 11),
      notes: 'Retain booking history',
    );
    await DaoJobActivity().insert(activity);
    return activity;
  }

  Future<void> cancel(Job job) async {
    await LifecycleEventDispatcher().dispatchJob(
      job.id,
      RejectJob.new,
      context: LifecycleContext(source: 'test.cancel'),
    );
  }

  test('migration archive fixture reads history and pending flags', () async {
    await testDb!.execute(
      File('test/sql/cancelled_schedule.sql').readAsStringSync(),
    );
    final row = (await testDb!.query(CancelledSchedule.table)).single;
    final activity = CancelledSchedule.activity(row);
    expect(activity.id, 900001);
    expect(activity.notes, 'Archived fixture');
    expect(activity.status, JobActivityStatus.confirmed);
    expect(row['calendar_pending'], 1);
    expect(row['reminder_pending'], 1);
  });

  test('cancellation retires only the pending schedule instruction', () async {
    final target = await job();
    final other = await job();
    for (final entry in [
      (target.id, 'Schedule job'),
      (target.id, 'Keep history'),
      (other.id, 'Schedule job'),
    ]) {
      await testDb!.insert('to_do', {
        'title': entry.$2,
        'priority': 'high',
        'status': 'open',
        'parent_type': 'job',
        'parent_id': entry.$1,
        'created_date': DateTime.now().toIso8601String(),
        'modified_date': DateTime.now().toIso8601String(),
      });
    }
    await cancel(target);
    expect(
      (await DaoToDo().getOpenByJob(target.id)).map((todo) => todo.title),
      ['Keep history'],
    );
    expect((await DaoToDo().getOpenByJob(other.id)).map((todo) => todo.title), [
      'Schedule job',
    ]);
  });

  for (final count in [0, 1, 3]) {
    test('cancel $count bookings preserves history and other jobs', () async {
      final target = await job();
      final other = await job();
      final unrelated = await booking(other);
      for (var i = 0; i < count; i++) {
        await booking(target);
      }
      final task = Task.forInsert(
        jobId: target.id,
        name: 'History',
        description: '',
        status: TaskStatus.inProgress,
      );
      await DaoTask().insert(task);
      await cancel(target);
      expect(await DaoJobActivity().getByJob(target.id), isEmpty);
      expect(await DaoJobActivity().getById(unrelated.id), isNotNull);
      expect(await DaoTask().getById(task.id), isNotNull);
      expect((await DaoJob().getById(target.id))!.status, JobStatus.rejected);
      final archived = await testDb!.query(
        CancelledSchedule.table,
        where: 'job_id = ?',
        whereArgs: [target.id],
      );
      expect(archived, hasLength(count));
      for (final row in archived) {
        expect(CancelledSchedule.activity(row).notes, 'Retain booking history');
      }
      await cancel(target);
      expect(await testDb!.query(CancelledSchedule.table), hasLength(count));
      await LifecycleEventDispatcher().dispatchJob(
        target.id,
        RestoreJob.new,
        context: LifecycleContext(source: 'test.restore'),
      );
      expect(await DaoJobActivity().getByJob(target.id), isEmpty);
    });
  }

  test('quote-and-job rejection also removes bookings', () async {
    final target = await job();
    await booking(target);
    final quote = Quote.forInsert(
      jobId: target.id,
      summary: 'Quote',
      description: '',
      totalAmount: MoneyEx.zero,
      state: QuoteState.sent,
    );
    await DaoQuote().insert(quote);
    await LifecycleEventDispatcher().dispatchQuote(
      quote.id,
      RejectQuoteAndJob.new,
      context: LifecycleContext(source: 'test.quoteCancel'),
    );
    expect(await DaoJobActivity().getByJob(target.id), isEmpty);
    expect(await testDb!.query(CancelledSchedule.table), hasLength(1));
  });

  test('rejection failure rolls back archive and booking removal', () async {
    final target = await job();
    final activity = await booking(target);
    final quote = Quote.forInsert(
      jobId: target.id,
      summary: 'Invoiced',
      description: '',
      totalAmount: MoneyEx.zero,
      state: QuoteState.invoiced,
    );
    await DaoQuote().insert(quote);
    await expectLater(cancel(target), throwsA(isA<LifecycleException>()));
    expect(await DaoJobActivity().getById(activity.id), isNotNull);
    expect(await testDb!.query(CancelledSchedule.table), isEmpty);
    expect((await DaoJob().getById(target.id))!.status, JobStatus.scheduled);
  });

  test(
    'failed and disabled deletions survive retries without duplicate work',
    () async {
      final target = await job();
      final first = await booking(target);
      final second = await booking(target);
      await cancel(target);
      final deleted = <int>[];
      final reminders = <int>[];
      var fail = true;
      var disabled = false;
      final cleanup = CancelledScheduleCleanup(
        db: testDb!,
        deleteCalendar: (activity) async {
          if (fail && activity.id == first.id) {
            throw StateError('offline');
          }
          if (disabled) {
            return ExternalCalendarSyncResult.disabled;
          }
          deleted.add(activity.id);
          return ExternalCalendarSyncResult.synced;
        },
        cancelReminder: (id) async {
          reminders.add(id);
        },
      );
      expect(await cleanup.retry(), 1);
      expect(deleted, [second.id]);
      expect(reminders, [first.id, second.id]);
      fail = false;
      disabled = true;
      expect(await cleanup.retry(), 1);
      disabled = false;
      expect(await cleanup.retry(), 0);
      expect(await cleanup.retry(), 0);
      expect(deleted, [second.id, first.id]);
      expect(reminders, [first.id, second.id]);
      expect(await testDb!.query(CancelledSchedule.table), hasLength(2));
    },
  );

  for (final result in [
    ExternalCalendarSyncResult.unavailable,
    ExternalCalendarSyncResult.signInRequired,
  ]) {
    test('$result and reminder failure remain visible for retry', () async {
      final target = await job();
      await booking(target);
      await cancel(target);
      final cleanup = CancelledScheduleCleanup(
        db: testDb!,
        deleteCalendar: (_) async => result,
        cancelReminder: (_) async => throw StateError('device offline'),
      );
      expect(await cleanup.retry(), 1);
      final row = (await testDb!.query(CancelledSchedule.table)).single;
      expect(row['calendar_pending'], 1);
      expect(row['reminder_pending'], 1);
    });
  }

  test('stale queued reminders cannot recreate cancelled bookings', () async {
    final target = await job();
    final activity = await booking(target);
    final cleanup = CancelledScheduleCleanup(
      db: testDb!,
      deleteCalendar: (_) async => ExternalCalendarSyncResult.synced,
      cancelReminder: (_) async {},
    );
    await cancel(target);
    await cleanup.retry();
    var created = false;
    await cleanup.syncReminderIfScheduled(activity.id, () async {
      created = true;
    });
    expect(created, isFalse);
  });

  test(
    'cleanup waits for an in-flight reminder write before cancellation',
    () async {
      final target = await job();
      final activity = await booking(target);
      final entered = Completer<void>();
      final release = Completer<void>();
      final operations = <String>[];
      final cleanup = CancelledScheduleCleanup(
        db: testDb!,
        deleteCalendar: (_) async => ExternalCalendarSyncResult.synced,
        cancelReminder: (_) async {
          operations.add('cancel');
        },
      );
      final writing = cleanup.syncReminderIfScheduled(activity.id, () async {
        entered.complete();
        await release.future;
        operations.add('schedule');
      });
      await entered.future;
      await cancel(target);
      final deleting = cleanup.retry();
      release.complete();
      await writing;
      expect(await deleting, 0);
      expect(operations, ['schedule', 'cancel']);
    },
  );

  test(
    'stale queued upsert cannot recreate a cancelled or restored booking',
    () async {
      final target = await job();
      final activity = await booking(target);
      final gateway = _Gateway();
      final service = GoogleCalendarSyncService(
        synchronize: (operation) async {
          await operation(ExternalCalendarSynchronizer(gateway));
          return ExternalCalendarSyncResult.synced;
        },
      );
      await cancel(target);
      await service.upsertActivity(activity: activity, job: target);
      expect(gateway.inserts, 0);
      await LifecycleEventDispatcher().dispatchJob(
        target.id,
        RestoreJob.new,
        context: LifecycleContext(source: 'test.restore'),
      );
      await service.upsertActivity(activity: activity, job: target);
      expect(gateway.inserts, 0);
    },
  );

  test(
    'cancellation during in-flight insert removes the newly created event',
    () async {
      final target = await job();
      final activity = await booking(target);
      final entered = Completer<void>();
      final release = Completer<void>();
      final gateway = _Gateway(
        onInsert: () async {
          entered.complete();
          await release.future;
        },
      );
      final service = GoogleCalendarSyncService(
        synchronize: (operation) async {
          await operation(ExternalCalendarSynchronizer(gateway));
          return ExternalCalendarSyncResult.synced;
        },
      );
      final pending = service.upsertActivity(activity: activity, job: target);
      await entered.future;
      await cancel(target);
      release.complete();
      await pending;
      expect(gateway.inserts, 1);
      expect(gateway.deletes, 1);
      expect(gateway.exists, isFalse);
    },
  );
}

class _Gateway implements ExternalCalendarGateway {
  _Gateway({this.onInsert});
  final Future<void> Function()? onInsert;
  var exists = false;
  var inserts = 0;
  var deletes = 0;
  @override
  Future<String?> findEventId({
    required String key,
    required String value,
  }) async => exists ? 'fixture-event' : null;
  @override
  Future<void> insert(ExternalCalendarEventDraft event) async {
    inserts++;
    await onInsert?.call();
    exists = true;
  }

  @override
  Future<void> update(String id, ExternalCalendarEventDraft event) async {}
  @override
  Future<void> delete(String id) async {
    deletes++;
    exists = false;
  }

  @override
  void close() {}
}
