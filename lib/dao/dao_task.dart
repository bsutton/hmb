import 'package:dcli_core/dcli_core.dart';
import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/_index.g.dart';
import '../util/money_ex.dart';
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
    final db = getDb();

    final results =
        await db.query(tableName, where: 'job_id = ?', whereArgs: [jobId]);

    final tasks = <Task>[];
    for (final result in results) {
      tasks.add(Task.fromMap(result));
    }
    return tasks;
  }

  Future<Task> getTaskForCheckListItem(CheckListItem item) async {
    final db = getDb();

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
    final photos = await DaoPhoto().getByTask(taskId);

    for (final photo in photos) {
      await DaoPhoto().delete(photo.id);

      // Delete the photo file from the disk
      if (exists(photo.filePath)) {
        delete(photo.filePath);
      }
    }
  }

  Future<Task> getTaskForCheckList(CheckList checkList) async {
    final db = getDb();

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
    final db = getDb();
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

  /// If [includeBilled] is true then we return the accured value since
  /// the [Job] started. If [includeBilled] is false then we only
  /// include labour/materials that haven't been billed.
  Future<TaskAccruedValue> getAccruedValue(
      {required Task task, required bool includeBilled}) async {
    final hourlyRate = await DaoTask().getHourlyRate(task);
    final billingType = await DaoTask().getBillingType(task);

    // Get task cost and effort using the new getTaskCost method
    final taskEstimatedCharges = await getTaskEstimates(task, hourlyRate);

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
            totalMaterialCharges += (item.actualMaterialCost ?? MoneyEx.zero)
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

  Future<TaskEstimatedValue> getTaskEstimates(
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
        estimatedMaterialsCharge: estimatedMaterialsCharge,
        estimatedLabour: estimatedLabourCharge);
  }

  /// Returns a list of Task with their associated costs.
  /// Tasks with a zero value are excluded.
  Future<List<TaskAccruedValue>> getTaskCostsByJob(
      {required int jobId, required bool includeBilled}) async {
    final tasks = await getTasksByJob(jobId);
    final taskCosts = <TaskAccruedValue>[];

    for (final task in tasks) {
      // Use the new getTaskCost method which now includes effortInHours
      final accruedValue =
          await getAccruedValue(task: task, includeBilled: includeBilled);

      if ((await accruedValue.earned) == MoneyEx.zero) {
        continue;
      }

      taskCosts.add(accruedValue);
    }

    return taskCosts;
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
    final db = getDb();

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

  Task get task => taskEstimatedValue.task;
}

class TaskEstimatedValue {
  TaskEstimatedValue({
    required this.task,
    required this.estimatedMaterialsCharge,
    required this.estimatedLabour,
  });

  Task task;

  /// Estimated material charges taken from
  /// [CheckListItem]s materials buy
  Money estimatedMaterialsCharge;

  /// Estimated labour (in hours) for the task taken
  /// from [CheckListItem]s of type [CheckListItemTypeEnum.labour]
  Fixed estimatedLabour;
}
