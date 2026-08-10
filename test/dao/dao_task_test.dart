import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test(
    'task estimateComplete defaults to false and persists updates',
    () async {
      final customer = Customer.forInsert(
        name: 'Estimate Customer',
        description: '',
        disbarred: false,
        customerType: CustomerType.residential,
        hourlyRate: MoneyEx.zero,
        billingContactId: null,
      );
      await DaoCustomer().insert(customer);

      final job = Job.forInsert(
        customerId: customer.id,
        summary: 'Estimate Job',
        description: '',
        siteId: null,
        contactId: null,
        billingContactId: null,
        status: JobStatus.inProgress,
        hourlyRate: MoneyEx.zero,
        bookingFee: MoneyEx.zero,
      );
      await DaoJob().insert(job);

      final task = Task.forInsert(
        jobId: job.id,
        name: 'Estimate Task',
        description: '',
        status: TaskStatus.awaitingApproval,
      );
      await DaoTask().insert(task);

      final inserted = (await DaoTask().getById(task.id))!;
      expect(inserted.estimateComplete, isFalse);
      expect(inserted.status, TaskStatus.awaitingApproval);

      await DaoTask().update(inserted.copyWith(estimateComplete: true));

      final updated = (await DaoTask().getById(task.id))!;
      expect(updated.estimateComplete, isTrue);
      expect(updated.status, TaskStatus.awaitingApproval);
    },
  );

  test('job estimates exclude completed tasks', () async {
    final customer = Customer.forInsert(
      name: 'Estimate Customer',
      description: '',
      disbarred: false,
      customerType: CustomerType.residential,
      hourlyRate: MoneyEx.zero,
      billingContactId: null,
    );
    await DaoCustomer().insert(customer);

    final job = Job.forInsert(
      customerId: customer.id,
      summary: 'Estimate Job',
      description: '',
      siteId: null,
      contactId: null,
      billingContactId: null,
      status: JobStatus.inProgress,
      hourlyRate: MoneyEx.zero,
      bookingFee: MoneyEx.zero,
    );
    await DaoJob().insert(job);

    final activeTask = await _insertEstimatedTask(
      job: job,
      name: 'Active estimate task',
      status: TaskStatus.awaitingApproval,
      unitCost: MoneyEx.fromInt(1000),
    );
    await _insertEstimatedTask(
      job: job,
      name: 'Completed estimate task',
      status: TaskStatus.completed,
      unitCost: MoneyEx.fromInt(2000),
    );

    final estimates = await DaoTask().getEstimatesForJob(job);

    expect(estimates.map((estimate) => estimate.task.id), [activeTask.id]);
  });
}

Future<Task> _insertEstimatedTask({
  required Job job,
  required String name,
  required TaskStatus status,
  required Money unitCost,
}) async {
  final task = Task.forInsert(
    jobId: job.id,
    name: name,
    description: '',
    status: status,
  );
  await DaoTask().insert(task);

  final item = TaskItem.forInsert(
    taskId: task.id,
    description: '$name item',
    itemType: TaskItemType.materialsBuy,
    margin: Percentage.zero,
    measurementType: MeasurementType.length,
    dimension1: Fixed.zero,
    dimension2: Fixed.zero,
    dimension3: Fixed.zero,
    units: Units.defaultUnits,
    url: '',
    purpose: '',
    labourEntryMode: LabourEntryMode.hours,
    chargeMode: ChargeMode.calculated,
    estimatedPrice: MaterialPrice.items(
      quantity: Fixed.one,
      unitCost: unitCost,
    ),
  );
  await DaoTaskItem().insert(item);
  return task;
}
