import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/task_effort_history.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test(
    'completed work compares recorded time without affecting billing',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.dollars(90),
      );
      final category = Category.forInsert(name: 'Painting');
      await DaoCategory().insert(category);
      final task = Task.forInsert(
        jobId: job.id,
        name: 'Walls',
        description: '',
        status: TaskStatus.completed,
        categoryId: category.id,
        effortQuantity: 20,
        effortUnit: 'm²',
        effortNotes: 'Easy access, two coats',
      );
      await DaoTask().insert(task);
      for (final finished in [true, true, false]) {
        await DaoTimeEntry().insert(
          TimeEntry.forInsert(
            taskId: task.id,
            startTime: DateTime(2026, 1, 1, 9),
            endTime: finished ? DateTime(2026, 1, 1, 10, 30) : null,
          ),
        );
      }
      await DaoTask().insert(
        Task.forInsert(
          jobId: job.id,
          name: 'Unfinished walls',
          description: '',
          status: TaskStatus.inProgress,
          categoryId: category.id,
        ),
      );
      final report = await TaskEffortHistory().load(search: 'PAINTING');
      expect(report, hasLength(1));
      expect(report.single.hours, 3);
      expect(report.single.hoursPerUnit, 0.15);
      expect(report.single.completedEntries, 2);
      expect(report.single.task.effortNotes, 'Easy access, two coats');
      expect(await TaskEffortHistory().load(search: 'no match'), isEmpty);
      expect(
        (await DaoTimeEntry().getByTask(task.id)).any((e) => e.billed),
        isFalse,
      );
      await DaoTask().update(
        task.copyWith(
          clearCategory: true,
          clearEffortQuantity: true,
          effortUnit: '',
        ),
      );
      final cleared = (await DaoTask().getById(task.id))!;
      expect(cleared.categoryId, isNull);
      expect(cleared.effortQuantity, isNull);
    },
  );

  test(
    'tasks without recorded time are not presented as measured zero',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: MoneyEx.dollars(90),
      );
      final task = Task.forInsert(
        jobId: job.id,
        name: 'Unknown effort',
        description: '',
        status: TaskStatus.completed,
      );
      await DaoTask().insert(task);
      final record = (await TaskEffortHistory().load(
        search: 'Unknown effort',
      )).single;
      expect(record.completedEntries, 0);
      expect(record.hoursPerUnit, isNull);
      expect(record.category, 'Uncategorised');
    },
  );
}
