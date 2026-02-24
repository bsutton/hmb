import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('markRejected sets task status to cancelled', () async {
    final task = await _insertTask(status: TaskStatus.inProgress);

    await DaoTask().markRejected(task.id);

    final reloaded = await DaoTask().getById(task.id);
    expect(reloaded?.status, TaskStatus.cancelled);
  });

  test('markUnrejected moves cancelled task to awaitingApproval', () async {
    final task = await _insertTask(status: TaskStatus.cancelled);

    await DaoTask().markUnrejected(task.id);

    final reloaded = await DaoTask().getById(task.id);
    expect(reloaded?.status, TaskStatus.awaitingApproval);
  });
}

Future<Task> _insertTask({required TaskStatus status}) async {
  final job = await createJobWithCustomer(
    billingType: BillingType.timeAndMaterial,
    hourlyRate: MoneyEx.zero,
    summary: 'Reject test job',
  );

  final task = Task.forInsert(
    jobId: job.id,
    name: 'Task',
    description: '',
    status: status,
  );
  await DaoTask().insert(task);
  return task;
}
