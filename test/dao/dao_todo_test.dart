import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
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

  test(
    'held job todos disappear from lists and reminders until resumed',
    () async {
      final job = await createJob(
        DateTime.now(),
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
      );
      final due = DateTime.now();
      final todo = ToDo.forInsert(
        title: 'Held job todo',
        dueDate: due,
        remindAt: due.add(const Duration(hours: 1)),
        parentType: ToDoParentType.job,
        parentId: job.id,
      );
      final personal = ToDo.forInsert(
        title: 'Personal todo',
        dueDate: due,
        remindAt: due.add(const Duration(hours: 1)),
      );
      await DaoToDo().insert(todo);
      await DaoToDo().insert(personal);
      job.status = JobStatus.onHold;
      await DaoJob().update(job);
      expect(
        (await DaoToDo().getFiltered(status: ToDoStatus.open)).map((t) => t.id),
        [personal.id],
      );
      expect(
        await DaoToDo().getFiltered(status: ToDoStatus.open, filter: 'Held'),
        isEmpty,
      );
      expect(
        (await DaoToDo().getDueByDate(LocalDate.today())).map((t) => t.id),
        [personal.id],
      );
      expect((await DaoToDo().getOpenWithReminders()).map((t) => t.id), [
        personal.id,
      ]);
      expect((await DaoToDo().getByJob(job.id)).single.status, ToDoStatus.open);
      job.status = JobStatus.inProgress;
      await DaoJob().update(job);
      expect(
        (await DaoToDo().getFiltered(status: ToDoStatus.open)).map((t) => t.id),
        contains(todo.id),
      );
      expect(
        (await DaoToDo().getDueByDate(LocalDate.today())).map((t) => t.id),
        contains(todo.id),
      );
      expect(
        (await DaoToDo().getOpenWithReminders()).map((t) => t.id),
        contains(todo.id),
      );
    },
  );

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
