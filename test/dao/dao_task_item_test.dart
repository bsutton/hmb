import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('wasReturned is true only when a linked return row exists', () async {
    final item = await _insertMaterialTaskItem();

    expect(await DaoTaskItem().wasReturned(item.id), isFalse);

    await DaoTaskItem().markAsReturned(
      item.id,
      Fixed.one,
      MoneyEx.fromInt(500),
    );

    expect(await DaoTaskItem().wasReturned(item.id), isTrue);
  });

  test('shopping excludes items from completed jobs', () async {
    final active = await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.inProgress,
      itemType: TaskItemType.materialsBuy,
      completed: false,
    );
    await _insertTaskItemForJob(
      jobStatus: JobStatus.completed,
      taskStatus: TaskStatus.inProgress,
      itemType: TaskItemType.materialsBuy,
      completed: false,
    );

    final shopping = await DaoTaskItem().getShoppingItems();

    expect(shopping.map((i) => i.id), contains(active.id));
    expect(shopping.length, 1);
  });

  test('packing excludes items from completed jobs', () async {
    final active = await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.inProgress,
      itemType: TaskItemType.materialsStock,
      completed: false,
    );
    await _insertTaskItemForJob(
      jobStatus: JobStatus.completed,
      taskStatus: TaskStatus.inProgress,
      itemType: TaskItemType.materialsStock,
      completed: false,
    );

    final packing = await DaoTaskItem().getPackingItems(
      showPreScheduledJobs: false,
      showPreApprovedTask: true,
    );

    expect(packing.map((i) => i.id), contains(active.id));
    expect(packing.length, 1);
  });
}

Future<TaskItem> _insertMaterialTaskItem() async {
  return _insertTaskItemForJob(
    jobStatus: JobStatus.startingStatus,
    taskStatus: TaskStatus.awaitingApproval,
    itemType: TaskItemType.materialsBuy,
    completed: true,
  );
}

Future<TaskItem> _insertTaskItemForJob({
  required JobStatus jobStatus,
  required TaskStatus taskStatus,
  required TaskItemType itemType,
  required bool completed,
}) async {
  final customer = Customer.forInsert(
    name: 'Cust',
    description: '',
    disbarred: false,
    customerType: CustomerType.residential,
    hourlyRate: MoneyEx.zero,
    billingContactId: null,
  );
  await DaoCustomer().insert(customer);

  final job = Job.forInsert(
    customerId: customer.id,
    summary: 'Job',
    description: '',
    siteId: null,
    contactId: null,
    billingContactId: null,
    status: jobStatus,
    hourlyRate: MoneyEx.zero,
    bookingFee: MoneyEx.zero,
  );
  await DaoJob().insert(job);

  final task = Task.forInsert(
    jobId: job.id,
    name: 'Task',
    description: '',
    status: taskStatus,
  );
  await DaoTask().insert(task);

  final item = TaskItem.forInsert(
    taskId: task.id,
    description: 'Paint',
    purpose: '',
    itemType: itemType,
    estimatedMaterialUnitCost: MoneyEx.fromInt(500),
    estimatedMaterialQuantity: Fixed.one,
    actualMaterialUnitCost: MoneyEx.fromInt(500),
    actualMaterialQuantity: Fixed.one,
    chargeMode: ChargeMode.calculated,
    margin: Percentage.zero,
    completed: completed,
    measurementType: MeasurementType.length,
    dimension1: Fixed.zero,
    dimension2: Fixed.zero,
    dimension3: Fixed.zero,
    units: Units.m,
    url: '',
    labourEntryMode: LabourEntryMode.hours,
  );
  await DaoTaskItem().insert(item);
  return item;
}
