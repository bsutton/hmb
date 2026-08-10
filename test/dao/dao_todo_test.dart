import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import 'invoice/utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('persists closed todo status', () async {
    final id = await DaoToDo().insert(
      ToDo.forInsert(title: 'Archive old note', status: ToDoStatus.closed),
    );

    final todo = await DaoToDo().getById(id);
    expect(todo, isNotNull);
    expect(todo!.status, ToDoStatus.closed);
  });

  test('only open todos have reminder notifications', () async {
    final remindAt = DateTime.now().add(const Duration(hours: 2));
    final open = ToDo.forInsert(title: 'Open', remindAt: remindAt);
    final pastOpen = ToDo.forInsert(
      title: 'Past open',
      remindAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
    final done = ToDo.forInsert(
      title: 'Done',
      remindAt: remindAt,
      status: ToDoStatus.done,
    );
    final closed = ToDo.forInsert(
      title: 'Closed',
      remindAt: remindAt,
      status: ToDoStatus.closed,
    );
    await DaoToDo().insert(open);
    await DaoToDo().insert(pastOpen);
    await DaoToDo().insert(done);
    await DaoToDo().insert(closed);

    final reminders = await DaoToDo().getOpenWithReminders();

    expect(reminders.map((todo) => todo.id), [open.id]);
    expect(
      (await DaoToDo().getOpenWithReminders(
        includePast: true,
      )).map((todo) => todo.id),
      [pastOpen.id, open.id],
    );
  });

  test('todos for every finalised job status have no reminders', () async {
    final now = DateTime.now();
    final activeJob = await createJob(
      now,
      BillingType.timeAndMaterial,
      hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
    );
    final activeTodo = ToDo.forInsert(
      title: 'Active job',
      remindAt: now.add(const Duration(hours: 2)),
      parentType: ToDoParentType.job,
      parentId: activeJob.id,
    );
    await DaoToDo().insert(activeTodo);

    for (final status in JobStatus.values.where(
      (status) => status.stage == JobStatusStage.finalised,
    )) {
      final job = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
      );
      job.status = status;
      await DaoJob().update(job);
      await DaoToDo().insert(
        ToDo.forInsert(
          title: status.name,
          remindAt: now.add(const Duration(hours: 2)),
          parentType: ToDoParentType.job,
          parentId: job.id,
        ),
      );
    }

    final reminders = await DaoToDo().getOpenWithReminders();

    expect(reminders.map((todo) => todo.id), [activeTodo.id]);
  });
}
