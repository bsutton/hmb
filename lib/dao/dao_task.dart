import 'package:dcli_core/dcli_core.dart';
import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/_index.g.dart';
import '../util/money_ex.dart';
import '../util/photo_meta.dart';
import 'dao.dart';
import 'dao_checklist.dart';
import 'dao_checklist_item.dart';
import 'dao_job.dart';
import 'dao_photo.dart';
import 'dao_time_entry.dart';

class DaoTask extends Dao<Task> {
  @override
  Task fromMap(Map<String, dynamic> map) => Task.fromMap(map);

  @override
  String get tableName => 'task';

  Future<List<Task>> getTasksByJob(int jobId) async {
    final db = withoutTransaction();

    final results =
        await db.query(tableName, where: 'job_id = ?', whereArgs: [jobId]);

    final tasks = <Task>[];
    for (final result in results) {
      tasks.add(Task.fromMap(result));
    }
    return tasks;
  }

  @override
  Future<int> insert(covariant Task entity, [Transaction? transaction]) async {
    final task = super.insert(entity, transaction);
    final newChecklist = CheckList.forInsert(
        name: 'default',
        description: 'Default Checklist',
        listType: CheckListType.owned);
    await DaoCheckList().insertForTask(newChecklist, entity);

    return task;
  }

  Future<Task> getTaskForCheckListItem(CheckListItem item) async {
    final db = withoutTransaction();

    final data = await db.rawQuery('''
select t.* 
from check_list_item cli
join check_list cl
  on cli.check_list_id = cl.id
join task_check_list tcl
  on tcl.check_list_id = cl.id
join task t
  on tcl.task_id = t.id
where cli.id =? 
''', [item.id]);

    return toList(data).first;
  }

  Future<void> deleteTaskPhotos(int taskId, {Transaction? transaction}) async {
    final photos = await DaoPhoto().getByParent(taskId, ParentType.task);

    for (final photo in photos) {
      await DaoPhoto().delete(photo.id);

      final absolutePathToPhoto =
          await PhotoMeta.fromPhoto(photo: photo).resolve();

      // Delete the photo file from the disk
      if (exists(absolutePathToPhoto)) {
        delete(absolutePathToPhoto);
      }
    }
  }

  Future<Task> getTaskForCheckList(CheckList checkList) async {
    final db = withoutTransaction();

    final data = await db.rawQuery('''
    SELECT t.* 
    FROM check_list cl
    JOIN task_check_list tcl ON tcl.check_list_id = cl.id
    JOIN task t ON tcl.task_id = t.id
    WHERE cl.id = ?
  ''', [checkList.id]);

    return toList(data).first;
  }

  Future<Task> getTask(CheckListItem item) async {
    final db = withoutTransaction();
    final data = await db.rawQuery('''
SELECT t.*
FROM task t
JOIN task_check_list tc ON t.id = tc.task_id
JOIN check_list cl ON tc.check_list_id = cl.id
JOIN check_list_item cli ON cl.id = cli.check_list_id
WHERE cli.id = ?
''', [item.id]);

    return toList(data).first;
  }

  Future<List<TaskAccruedValue>> getAccruedValueForJob({required int jobId, required bool includedBilled}) async {
    final tasks = await DaoTask().getTasksByJob(jobId);

    final value = <TaskAccruedValue>[];
    for (final task in tasks) {
      value.add(await getAccruedValueForTask(task: task, includeBilled: includedBilled));
    }

    return value;
  }

  /// If [includeBilled] is true then we return the accured value since
  /// the [Job] started. If [includeBilled] is false then we only
  /// include labour/materials that haven't been billed.
  Future<TaskAccruedValue> getAccruedValueForTask(
      {required Task task, required bool includeBilled}) async {
    final hourlyRate = await DaoTask().getHourlyRate(task);
    final billingType = await DaoTask().getBillingType(task);

    // Get task cost and effort using the new getTaskCost method
    final taskEstimatedCharges = await getEstimateForTask(task, hourlyRate);

    var totalEarnedLabour = Fixed.zero;
    var totalMaterialCharges = MoneyEx.zero;

    if (billingType == BillingType.timeAndMaterial) {
      final timeEntries = await DaoTimeEntry().getByTask(task.id);
      for (final timeEntry in timeEntries) {
        if ((includeBilled && timeEntry.billed) || !timeEntry.billed) {
          totalEarnedLabour += timeEntry.hours;
        }
      }

      /// Material costs.
      for (final item in await DaoCheckListItem().getByTask(task.id)) {
        if (item.itemTypeId == CheckListItemTypeEnum.materialsBuy.id) {
          if ((includeBilled && item.billed) || !item.billed) {
            // Materials and tools to be purchased
            totalMaterialCharges +=
                (item.actualMaterialUnitCost ?? MoneyEx.zero)
                    .multiplyByFixed(item.actualMaterialQuantity ?? Fixed.one);
          }
        }
      }
    } else // fixed price
    {
      totalEarnedLabour = taskEstimatedCharges.estimatedLabour;
      totalMaterialCharges += taskEstimatedCharges.estimatedMaterialsCharge;
    }

    return TaskAccruedValue(
        taskEstimatedValue: taskEstimatedCharges,
        earnedMaterialCharges: totalMaterialCharges,
        earnedLabour: totalEarnedLabour);
  }

  /// Returns a estimates for each Task associated with [jobId]
  /// Tasks with a zero value are excluded.
  Future<List<TaskEstimatedValue>> getEstimatesForJob(int jobId) async {
    final tasks = await getTasksByJob(jobId);

    final estimates = <TaskEstimatedValue>[];
    for (final task in tasks) {
      final hourlyRate = await DaoTask().getHourlyRate(task);
      final estimate = await getEstimateForTask(task, hourlyRate);
      if (!estimate.total.isZero) {
        estimates.add(estimate);
      }
    }

    return estimates;
  }

  Future<TaskEstimatedValue> getEstimateForTask(
      Task task, Money hourlyRate) async {
    var estimatedMaterialsCharge = MoneyEx.zero;
    var estimatedLabourCharge = Fixed.zero;

    // Get checklist items for the task
    final checkListItems = await DaoCheckListItem().getByTask(task.id);

    final billingType = await DaoTask().getBillingType(task);

    for (final item in checkListItems) {
      if (item.itemTypeId == CheckListItemTypeEnum.labour.id) {
        // Labour check list item
        estimatedLabourCharge += item.estimatedLabourHours!;
      } else if (item.itemTypeId == CheckListItemTypeEnum.materialsBuy.id) {
        // Materials and tools to be purchased
        estimatedMaterialsCharge += item.estimatedMaterialUnitCost!
            .multiplyByFixed(item.estimatedMaterialQuantity!);
      }
    }

    if (billingType == BillingType.timeAndMaterial) {
      // Calculate time entries cost
      final timeEntries = await DaoTimeEntry().getByTask(task.id);
      for (final entry in timeEntries.where((entry) => !entry.billed)) {
        final duration = entry.duration.inMinutes / 60;
        estimatedMaterialsCharge +=
            hourlyRate.multiplyByFixed(Fixed.fromNum(duration));
      }
    }

    return TaskEstimatedValue(
        task: task,
        hourlyRate: hourlyRate,
        estimatedMaterialsCharge: estimatedMaterialsCharge,
        estimatedLabour: estimatedLabourCharge);
  }

  // Future<Money> getTimeAndMaterialEarnings(Task task, Money hourlyRate)
  //   async {
  //   assert(task.billingType == BillingType.timeAndMaterial,
  //       'Can only be called for tasks billed by TimeAndMaterials');
  //   var totalCost = MoneyEx.zero;

  //   // Get all time entries for the task
  //   final timeEntries = await DaoTimeEntry().getByTask(task.id);
  //   for (final entry in timeEntries.where((entry) => !entry.billed)) {
  //     final duration = entry.duration.inMinutes / 60;
  //     totalCost += hourlyRate.multiplyByFixed(Fixed.fromNum(duration));
  //   }

  //   // Get all checklist items for the task
  //   final checkListItems = await DaoCheckListItem().getByTask(task.id);
  //   for (final item in checkListItems.where((item) => !item.billed)) {
  //     totalCost += item.estimatedMaterialUnitCost!
  //         .multiplyByFixed(item.estimatedMaterialQuantity!);
  //   }

  //   return totalCost;
  // }

  @override
  JuneStateCreator get juneRefresher => TaskState.new;

  Future<void> deleteByJob(int id, {Transaction? transaction}) async {
    final db = withinTransaction(transaction);

    final tasks = await getTasksByJob(id);

    for (final task in tasks) {
      await DaoTimeEntry().deleteByTask(task.id, transaction);
      await DaoCheckList().deleteByTask(task.id, transaction);
      await deleteTaskPhotos(task.id, transaction: transaction);
    }

    // Delete tasks associated with the job
    await db.delete(
      'task',
      where: 'job_id = ?',
      whereArgs: [id],
    );
  }

  Future<Money> getHourlyRate(Task task) async =>
      DaoJob().getHourlyRate(task.jobId);

  Future<BillingType> getBillingType(Task task) async {
    final job = await DaoJob().getById(task.jobId);

    return task.billingType ?? job?.billingType ?? BillingType.timeAndMaterial;
  }
}

/// Used to notify the UI that the time entry has changed.
class TaskState extends JuneState {
  TaskState();
}

/// Holds the value earned from labour and materials
/// for work that has been completed.
/// For FixedPrice this is based on the estimates
/// for Time and Materials this is based on actuals.
class TaskAccruedValue {
  TaskAccruedValue(
      {required this.taskEstimatedValue,
      required this.earnedMaterialCharges,
      required this.earnedLabour});
  final TaskEstimatedValue taskEstimatedValue;

  /// The total worth of materials that have
  /// been marked as completd.
  /// For FixedPrice
  /// Taken from the estimated materials cost.
  /// For Time And Materials
  /// Taken from the actual materials cost.
  final Money earnedMaterialCharges;

  /// Stored as decimal hours
  /// For FixedPrice
  /// This is taken from the estimated labour costs.
  ///
  /// For Time and Materials
  /// This is taken from completed [TimeEntry]s
  Fixed earnedLabour;

  /// The total of labour changes and materials
  Future<Money> get earned async =>
      earnedMaterialCharges +
      (await DaoTask().getHourlyRate(taskEstimatedValue.task))
          .multiplyByFixed(earnedLabour);

  /// The total of labour changes and materials
  Future<Money> get quoted async =>
      taskEstimatedValue.estimatedMaterialsCharge +
      (await DaoTask().getHourlyRate(taskEstimatedValue.task))
          .multiplyByFixed(taskEstimatedValue.estimatedLabour);

  Task get task => taskEstimatedValue.task;
}

class TaskEstimatedValue {
  TaskEstimatedValue({
    required this.task,
    required this.estimatedMaterialsCharge,
    required this.estimatedLabour,
    required this.hourlyRate,
  });

  Task task;
  Money hourlyRate;

  /// Estimated material charges taken from
  /// [CheckListItem]s materials buy
  Money estimatedMaterialsCharge;

  /// Estimated labour (in hours) for the task taken
  /// from [CheckListItem]s of type [CheckListItemTypeEnum.labour]
  Fixed estimatedLabour;

  Money get estimatedLabourCharge =>
      hourlyRate.multiplyByFixed(estimatedLabour);

  Money get total => estimatedMaterialsCharge + estimatedLabourCharge;
}
