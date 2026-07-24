import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/util/dart/exceptions.dart';
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

  test('shopping history ranges calculate rolling cutoffs', () {
    final reference = DateTime(2026, 7, 24, 12);

    expect(
      ShoppingHistoryRange.last7Days.cutoff(reference),
      DateTime(2026, 7, 17, 12),
    );
    expect(
      ShoppingHistoryRange.last30Days.cutoff(reference),
      DateTime(2026, 6, 24, 12),
    );
    expect(
      ShoppingHistoryRange.last90Days.cutoff(reference),
      DateTime(2026, 4, 25, 12),
    );
    expect(
      ShoppingHistoryRange.lastYear.cutoff(reference),
      DateTime(2025, 7, 24, 12),
    );
    expect(ShoppingHistoryRange.all.cutoff(reference), isNull);
  });

  test(
    'purchased history supports ranges, consumables, and inactive jobs',
    () async {
      final recent = await _insertTaskItemForJob(
        jobStatus: JobStatus.inProgress,
        taskStatus: TaskStatus.inProgress,
        itemType: TaskItemType.materialsBuy,
        completed: true,
      );
      final recentJob = await _jobForItem(recent);
      final oldConsumable = await _insertTaskItemForExistingJob(
        jobId: recentJob.id,
        itemType: TaskItemType.consumablesBuy,
        completed: true,
      );
      await _setModifiedDate(
        oldConsumable,
        DateTime.now().subtract(const Duration(days: 60)),
      );

      final inactive = await _insertTaskItemForJob(
        jobStatus: JobStatus.completed,
        taskStatus: TaskStatus.completed,
        itemType: TaskItemType.toolsBuy,
        completed: true,
      );
      final inactiveJob = await _jobForItem(inactive);

      final recentOnly = await DaoTaskItem().getPurchasedItems(
        historyRange: ShoppingHistoryRange.last30Days,
        jobs: [recentJob, inactiveJob],
      );
      expect(recentOnly.map((item) => item.id), [recent.id]);

      final activeHistory = await DaoTaskItem().getPurchasedItems(
        historyRange: ShoppingHistoryRange.all,
        jobs: [recentJob, inactiveJob],
      );
      expect(
        activeHistory.map((item) => item.id),
        containsAll([recent.id, oldConsumable.id]),
      );
      expect(
        activeHistory.map((item) => item.id),
        isNot(contains(inactive.id)),
      );

      final allHistory = await DaoTaskItem().getPurchasedItems(
        historyRange: ShoppingHistoryRange.all,
        jobs: [recentJob, inactiveJob],
        includeInactiveJobs: true,
      );
      expect(
        allHistory.map((item) => item.id),
        containsAll([recent.id, oldConsumable.id, inactive.id]),
      );
    },
  );

  test('returned history supports ranges and inactive jobs', () async {
    final recentPurchase = await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.inProgress,
      itemType: TaskItemType.materialsBuy,
      completed: true,
    );
    final recentJob = await _jobForItem(recentPurchase);
    await DaoTaskItem().markAsReturned(
      recentPurchase.id,
      Fixed.one,
      MoneyEx.fromInt(500),
    );
    final recentReturn = (await DaoTaskItem().getByTask(
      recentPurchase.taskId,
    )).singleWhere((item) => item.isReturn);

    final inactivePurchase = await _insertTaskItemForJob(
      jobStatus: JobStatus.completed,
      taskStatus: TaskStatus.completed,
      itemType: TaskItemType.toolsBuy,
      completed: true,
    );
    final inactiveJob = await _jobForItem(inactivePurchase);
    await DaoTaskItem().markAsReturned(
      inactivePurchase.id,
      Fixed.one,
      MoneyEx.fromInt(500),
    );
    final inactiveReturn = (await DaoTaskItem().getByTask(
      inactivePurchase.taskId,
    )).singleWhere((item) => item.isReturn);
    await _setModifiedDate(
      inactiveReturn,
      DateTime.now().subtract(const Duration(days: 60)),
    );

    final recentOnly = await DaoTaskItem().getReturnedItems(
      historyRange: ShoppingHistoryRange.last30Days,
      jobs: [recentJob, inactiveJob],
      includeInactiveJobs: true,
    );
    expect(recentOnly.map((item) => item.id), [recentReturn.id]);

    final activeHistory = await DaoTaskItem().getReturnedItems(
      historyRange: ShoppingHistoryRange.all,
      jobs: [recentJob, inactiveJob],
    );
    expect(activeHistory.map((item) => item.id), [recentReturn.id]);

    final allHistory = await DaoTaskItem().getReturnedItems(
      historyRange: ShoppingHistoryRange.all,
      jobs: [recentJob, inactiveJob],
      includeInactiveJobs: true,
    );
    expect(
      allHistory.map((item) => item.id),
      containsAll([recentReturn.id, inactiveReturn.id]),
    );
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

  test('receipt return matching uses returned shopping items', () async {
    final item = await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.inProgress,
      itemType: TaskItemType.materialsBuy,
      completed: true,
    );
    final task = (await DaoTask().getById(item.taskId))!;

    await DaoTaskItem().markAsReturned(
      item.id,
      Fixed.one,
      MoneyEx.fromInt(500),
    );

    final returned = await DaoTaskItem().getReturnedItemsForReceiptLink(
      jobId: task.jobId,
    );
    final purchased = await DaoTaskItem().getPurchasedItemsForReceiptLink(
      jobId: task.jobId,
    );

    expect(returned, hasLength(1));
    expect(returned.single.isReturn, isTrue);
    expect(returned.single.sourceTaskItemId, item.id);
    expect(
      purchased.map((candidate) => candidate.id),
      isNot(contains(returned.single.id)),
    );
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

  test('shopping excludes items for inactive task statuses', () async {
    final active = await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.inProgress,
      itemType: TaskItemType.materialsBuy,
      completed: false,
    );
    await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.completed,
      itemType: TaskItemType.materialsBuy,
      completed: false,
    );
    await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.onHold,
      itemType: TaskItemType.materialsBuy,
      completed: false,
    );
    await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.cancelled,
      itemType: TaskItemType.materialsBuy,
      completed: false,
    );

    final shopping = await DaoTaskItem().getShoppingItems();

    expect(shopping.map((i) => i.id), contains(active.id));
    expect(shopping.length, 1);
  });

  test('packing excludes items for inactive task statuses', () async {
    final active = await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.inProgress,
      itemType: TaskItemType.materialsStock,
      completed: false,
    );
    await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.completed,
      itemType: TaskItemType.materialsStock,
      completed: false,
    );
    await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.onHold,
      itemType: TaskItemType.materialsStock,
      completed: false,
    );
    await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.cancelled,
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

  test('update persists direct charge mode and completion flag', () async {
    final item = await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.inProgress,
      itemType: TaskItemType.materialsBuy,
      completed: false,
    );

    final updated = item.copyWith(
      chargeMode: ChargeMode.userDefined,
      totalLineCharge: Money.fromInt(12345, isoCode: 'AUD'),
      completed: true,
    );
    await DaoTaskItem().update(updated);

    final reloaded = (await DaoTaskItem().getById(item.id))!;
    expect(reloaded.chargeMode, ChargeMode.userDefined);
    expect(reloaded.userDefinedCharge, Money.fromInt(12345, isoCode: 'AUD'));
    expect(reloaded.completed, isTrue);
  });

  test(
    'marking shopping item complete keeps invoice charge calculated',
    () async {
      final item = await _insertTaskItemForJob(
        jobStatus: JobStatus.inProgress,
        taskStatus: TaskStatus.inProgress,
        itemType: TaskItemType.materialsBuy,
        completed: false,
      );
      await DaoTaskItem().update(
        item.copyWith(
          chargeMode: ChargeMode.userDefined,
          totalLineCharge: Money.fromInt(99999, isoCode: 'AUD'),
        ),
      );

      final reloaded = (await DaoTaskItem().getById(item.id))!;
      await DaoTaskItem().markAsCompleted(
        item: reloaded,
        materialUnitCost: MoneyEx.fromInt(200),
        materialQuantity: Fixed.parse('3'),
      );

      final completed = (await DaoTaskItem().getById(item.id))!;
      expect(completed.chargeMode, ChargeMode.calculated);
      expect(completed.userDefinedCharge, isNull);
      expect(
        completed.getTotalLineCharge(BillingType.timeAndMaterial, MoneyEx.zero),
        MoneyEx.fromInt(600),
      );
    },
  );

  test('completed material update fills missing actual costs', () async {
    final item = await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.inProgress,
      itemType: TaskItemType.materialsBuy,
      completed: false,
      includeActuals: false,
    );

    final updated = item.copyWith(completed: true);
    await DaoTaskItem().update(updated);

    final reloaded = (await DaoTaskItem().getById(item.id))!;
    expect(reloaded.completed, isTrue);
    expect(reloaded.actualMaterialUnitCost, MoneyEx.fromInt(500));
    expect(reloaded.actualMaterialQuantity, Fixed.one);
    expect(reloaded.actualCost, MoneyEx.fromInt(500));
    expect(reloaded.chargeMode, ChargeMode.calculated);
  });

  test('receipt can link to multiple task items', () async {
    final firstItem = await _insertTaskItemForJob(
      jobStatus: JobStatus.inProgress,
      taskStatus: TaskStatus.inProgress,
      itemType: TaskItemType.materialsBuy,
      completed: true,
    );
    final task = (await DaoTask().getById(firstItem.taskId))!;
    final secondItem = await _insertTaskItemForExistingJob(
      jobId: task.jobId,
      itemType: TaskItemType.toolsBuy,
      completed: true,
    );
    final supplier = Supplier.forInsert(
      name: 'Receipt Supplier',
      businessNumber: '',
      description: '',
      bsb: '',
      accountNumber: '',
      service: '',
    );
    await DaoSupplier().insert(supplier);
    final receipt = Receipt.forInsert(
      receiptDate: DateTime.now(),
      jobId: task.jobId,
      supplierId: supplier.id,
      totalExcludingTax: MoneyEx.fromInt(10000),
      tax: MoneyEx.fromInt(1000),
      totalIncludingTax: MoneyEx.fromInt(11000),
    );
    await DaoReceipt().insert(receipt);

    await DaoReceipt().replaceTaskItemLinks(receipt.id, [
      firstItem.id,
      secondItem.id,
    ]);

    expect(
      await DaoReceipt().getLinkedTaskItemIds(receipt.id),
      equals([firstItem.id, secondItem.id]),
    );
    expect(await DaoReceipt().countLinkedTaskItems(receipt.id), 2);
    expect(() => DaoReceipt().delete(receipt.id), throwsA(isA<HMBException>()));

    await DaoReceipt().replaceTaskItemLinks(receipt.id, [secondItem.id]);

    expect(
      await DaoReceipt().getLinkedTaskItemIds(receipt.id),
      equals([secondItem.id]),
    );
  });
}

Future<TaskItem> _insertMaterialTaskItem() => _insertTaskItemForJob(
  jobStatus: JobStatus.startingStatus,
  taskStatus: TaskStatus.awaitingApproval,
  itemType: TaskItemType.materialsBuy,
  completed: true,
);

Future<TaskItem> _insertTaskItemForJob({
  required JobStatus jobStatus,
  required TaskStatus taskStatus,
  required TaskItemType itemType,
  required bool completed,
  bool includeActuals = true,
}) async {
  final unique = DateTime.now().microsecondsSinceEpoch;
  final customer = Customer.forInsert(
    name: 'Cust-$unique',
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
    actualMaterialUnitCost: includeActuals ? MoneyEx.fromInt(500) : null,
    actualMaterialQuantity: includeActuals ? Fixed.one : null,
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

Future<TaskItem> _insertTaskItemForExistingJob({
  required int jobId,
  required TaskItemType itemType,
  required bool completed,
}) async {
  final task = Task.forInsert(
    jobId: jobId,
    name: 'Task 2',
    description: '',
    status: TaskStatus.inProgress,
  );
  await DaoTask().insert(task);

  final item = TaskItem.forInsert(
    taskId: task.id,
    description: 'Second item',
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

Future<Job> _jobForItem(TaskItem item) async {
  final task = (await DaoTask().getById(item.taskId))!;
  return (await DaoJob().getById(task.jobId))!;
}

Future<void> _setModifiedDate(TaskItem item, DateTime modifiedDate) async {
  await testDb!.update(
    DaoTaskItem.tableName,
    {'modified_date': modifiedDate.toIso8601String()},
    where: 'id = ?',
    whereArgs: [item.id],
  );
}
