import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import 'invoice/utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  group('DaoActivity tests', () {
    test('creates and lists manual activity', () async {
      final job = await createJob(
        DateTime.now(),
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
      );

      await DaoActivity().insert(
        Activity.forInsert(
          jobId: job.id,
          type: ActivityType.note,
          summary: 'Called customer',
          details: 'Discussed scheduling options.',
        ),
      );

      final activities = await DaoActivity().getByJob(job.id);
      expect(activities.length, 1);
      expect(activities.first.summary, 'Called customer');
      expect(activities.first.type, ActivityType.note);
    });

    test('time tracking adds one work-day activity per day', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
      );
      final task = await createTask(job, 'Work task');

      await DaoTimeEntry().insert(
        TimeEntry.forInsert(
          taskId: task.id,
          startTime: now.copyWith(hour: 9, minute: 0),
          endTime: now.copyWith(hour: 10, minute: 0),
          note: 'Morning work',
        ),
      );

      await DaoTimeEntry().insert(
        TimeEntry.forInsert(
          taskId: task.id,
          startTime: now.copyWith(hour: 13, minute: 0),
          endTime: now.copyWith(hour: 14, minute: 0),
          note: 'Afternoon work',
        ),
      );

      final activities = await DaoActivity().getByJob(job.id);
      final worked = activities
          .where((a) => a.type == ActivityType.workDay)
          .toList();
      expect(worked.length, 1);
      expect(worked.first.source, ActivitySource.system);
    });
  });
}
