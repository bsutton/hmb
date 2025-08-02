/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:dcli_core/dcli_core.dart' as core;
import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/entity.g.dart';
import '../util/money_ex.dart';
import '../util/photo_meta.dart';
import 'dao.g.dart';

class DaoTask extends Dao<Task> {
  @override
  Task fromMap(Map<String, dynamic> map) => Task.fromMap(map);

  @override
  String get tableName => 'task';

  Future<List<Task>> getTasksByJob(int jobId) async {
    final db = withoutTransaction();

    final results = await db.query(
      tableName,
      where: 'job_id = ?',
      whereArgs: [jobId],
    );

    final tasks = <Task>[];
    for (final result in results) {
      tasks.add(Task.fromMap(result));
    }
    return tasks;
  }

  @override
  Future<int> insert(covariant Task entity, [Transaction? transaction]) {
    final task = super.insert(entity, transaction);

    return task;
  }

  //   Future<Task> getTaskForCheckListItem(CheckListItem item) async {
  //     final db = withoutTransaction();

  //     final data = await db.rawQuery('''
  // select t.*
  // from task_item cli
  // join check_list cl
  //   on cli.check_list_id = cl.id
  // join task_check_list tcl
  //   on tcl.check_list_id = cl.id
  // join task t
  //   on tcl.task_id = t.id
  // where cli.id =?
  // ''', [item.id]);

  //     return toList(data).first;
  //   }

  Future<Task?> getForPhoto(Photo photo) async {
    assert(
      photo.parentType == ParentType.task,
      'The photo must be owned by Task',
    );

    return getById(photo.parentId);
  }

  Future<void> deleteTaskPhotos(int taskId, {Transaction? transaction}) async {
    final photos = await DaoPhoto().getByParent(taskId, ParentType.task);

    for (final photo in photos) {
      await DaoPhoto().delete(photo.id);

      final absolutePathToPhoto = await PhotoMeta.fromPhoto(
        photo: photo,
      ).resolve();

      // Delete the photo file from the disk
      if (core.exists(absolutePathToPhoto)) {
        core.delete(absolutePathToPhoto);
      }
    }
  }

  Future<Task> getTaskForItem(TaskItem item) async {
    final db = withoutTransaction();

    final data = await db.rawQuery(
      '''
SELECT t.*
FROM task t
JOIN task_item ti ON t.id = ti.task_id
WHERE ti.id = ?
''',
      [item.id],
    );

    if (data.isNotEmpty) {
      return Task.fromMap(data.first);
    } else {
      throw Exception('No task found for the provided task item.');
    }
  }

  Future<List<TaskAccruedValue>> getAccruedValueForJob({
    required int jobId,
    required bool includedBilled,
  }) async {
    final tasks = await DaoTask().getTasksByJob(jobId);

    final value = <TaskAccruedValue>[];
    for (final task in tasks) {
      value.add(
        await getAccruedValueForTask(task: task, includeBilled: includedBilled),
      );
    }

    return value;
  }

  /// If [includeBilled] is true then we return the accured value since
  /// the [Job] started. If [includeBilled] is false then we only
  /// include labour/materials that haven't been billed.
  Future<TaskAccruedValue> getAccruedValueForTask({
    required Task task,
    required bool includeBilled,
  }) async {
    final hourlyRate = await DaoTask().getHourlyRate(task);
    final billingType = await DaoTask().getBillingType(task);

    // Get task cost and effort using the new getTaskCost method
    final taskEstimatedCharges = await getEstimateForTask(task, hourlyRate);

    var totalEarnedLabour = MoneyEx.zero;
    var totalMaterialCharges = MoneyEx.zero;

    if (billingType == BillingType.timeAndMaterial) {
      final timeEntries = await DaoTimeEntry().getByTask(task.id);
      for (final timeEntry in timeEntries) {
        if ((includeBilled && timeEntry.billed) || !timeEntry.billed) {
          totalEarnedLabour += hourlyRate.multiplyByFixed(timeEntry.hours);
        }
      }

      /// Material costs.
      for (final item in await DaoTaskItem().getByTask(task.id)) {
        if (item.itemType == TaskItemType.materialsBuy ||
            item.itemType == TaskItemType.materialsStock ||
            item.itemType == TaskItemType.consumablesBuy ||
            item.itemType == TaskItemType.consumablesStock) {
          if ((includeBilled && item.billed) || !item.billed) {
            // Materials and tools to be purchased
            totalMaterialCharges +=
                (item.actualMaterialUnitCost ?? MoneyEx.zero).multiplyByFixed(
                  item.actualMaterialQuantity ?? Fixed.one,
                );
          }
        }
      }
    } else // fixed price
    {
      totalEarnedLabour = taskEstimatedCharges.estimatedLabourCharge;
      totalMaterialCharges += taskEstimatedCharges.estimatedMaterialsCharge;
    }

    return TaskAccruedValue(
      taskEstimatedValue: taskEstimatedCharges,
      earnedMaterialCharges: totalMaterialCharges,
      earnedLabourCharges: totalEarnedLabour,
      hourlyRate: hourlyRate,
    );
  }

  /// Returns a estimates for each Task associated with [jobId]
  /// Tasks with a zero value are excluded.
  Future<List<TaskEstimatedValue>> getEstimatesForJob(int jobId) async {
    final tasks = await getTasksByJob(jobId);

    final estimates = <TaskEstimatedValue>[];
    for (final task in tasks) {
      final hourlyRate = await DaoTask().getHourlyRate(task);
      final taskStatus = task.status;

      if (!taskStatus.isWithdrawn()) {
        final estimate = await getEstimateForTask(task, hourlyRate);
        if (!estimate.total.isZero) {
          estimates.add(estimate);
        }
      }
    }

    return estimates;
  }

  Future<TaskEstimatedValue> getEstimateForTask(
    Task task,
    Money hourlyRate,
  ) async {
    var estimatedMaterialsCharge = MoneyEx.zero;
    var estimatedLabourCharge = MoneyEx.zero;
    var estimatedLabourHours = Fixed.zero;

    // Get checklist items for the task
    final taskItems = await DaoTaskItem().getByTask(task.id);

    final billingType = await DaoTask().getBillingType(task);

    for (final item in taskItems) {
      if (item.itemType == TaskItemType.labour) {
        // Labour check list item
        estimatedLabourCharge += item.calcLabourCharges(hourlyRate);
        estimatedLabourHours += item.estimatedLabourHours ?? Fixed.zero;
      } else if (item.itemType == TaskItemType.materialsBuy) {
        // Materials and tools to be purchased
        estimatedMaterialsCharge += item.calcMaterialCharges(billingType);
      }
    }

    if (billingType == BillingType.timeAndMaterial) {
      // Calculate time entries cost
      final timeEntries = await DaoTimeEntry().getByTask(task.id);
      for (final entry in timeEntries.where((entry) => !entry.billed)) {
        estimatedLabourCharge += entry.calcLabourCharge(hourlyRate);
        estimatedLabourHours += entry.calcHours();
      }
    }

    return TaskEstimatedValue(
      task: task,
      hourlyRate: hourlyRate,
      estimatedMaterialsCharge: estimatedMaterialsCharge,
      estimatedLabourCharge: estimatedLabourCharge,
      estimatedLabourHours: estimatedLabourHours,
    );
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
      await delete(task.id, transaction);
    }

    // Delete tasks associated with the job
    await db.delete('task', where: 'job_id = ?', whereArgs: [id]);
  }

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    await DaoTimeEntry().deleteByTask(id, transaction);
    await DaoTaskItem().deleteByTask(id, transaction);
    await deleteTaskPhotos(id, transaction: transaction);
    await DaoWorkAssignmentTask().deleteByTask(id, transaction: transaction);
    await super.delete(id);
    return id;
  }

  Future<Money> getHourlyRate(Task task) => DaoJob().getHourlyRate(task.jobId);

  Future<BillingType> getBillingType(Task task) async {
    final job = await DaoJob().getById(task.jobId);

    // return task.billingType ?? job?.billingType ?? BillingType.timeAndMaterial;
    return job?.billingType ?? BillingType.timeAndMaterial;
  }

  Future<BillingType> getBillingTypeByTaskItem(TaskItem taskItem) async {
    final db = withoutTransaction();

    final data = await db.rawQuery(
      '''
SELECT 
  t.billing_type AS task_billing_type,
  j.billing_type AS job_billing_type
FROM task_item ti
JOIN task t ON ti.task_id = t.id
JOIN job j ON t.job_id = j.id
WHERE ti.id = ?
''',
      [taskItem.id],
    );

    if (data.isNotEmpty) {
      final taskBillingType = data.first['task_billing_type'] as String?;
      final jobBillingType = data.first['job_billing_type'] as String?;

      // Return the task's billing type if present; otherwise, the job's
      // billing type.
      // Default to BillingType.timeAndMaterial if both are null.
      return BillingType.values.firstWhere(
        (e) => e.name == (taskBillingType ?? jobBillingType),
        orElse: () => BillingType.timeAndMaterial,
      );
    }

    throw Exception('No billing type found for the provided TaskItem.');
  }

  Future<void> markRejected(int taskId) async {
    final task = await getById(taskId);

    task?.status = TaskStatus.cancelled;

    await update(task!);
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
  TaskAccruedValue({
    required this.taskEstimatedValue,
    required this.earnedMaterialCharges,
    required this.earnedLabourCharges,
    required Money hourlyRate,
  }) : earnedLabourHours = hourlyRate == MoneyEx.zero
           ? Fixed.zero
           : earnedLabourCharges.divideByFixed(hourlyRate.amount).amount;

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
  Money earnedLabourCharges;

  /// This is a derived value becase if the item is estimated
  /// in dollars we don't have an actual number of hours.
  /// In this case we dived the charge by the tasks hourly rate.
  Fixed earnedLabourHours;

  Fixed get estimatedLabourHours => taskEstimatedValue.estimatedLabourHours;

  /// The total of labour changes and materials
  Future<Money> get earned async => earnedMaterialCharges + earnedLabourCharges;

  /// The total of labour changes and materials
  Future<Money> get quoted async =>
      taskEstimatedValue.estimatedMaterialsCharge +
      taskEstimatedValue.estimatedLabourCharge;

  Task get task => taskEstimatedValue.task;
}

class TaskEstimatedValue {
  TaskEstimatedValue({
    required this.task,
    required this.estimatedMaterialsCharge,
    required this.estimatedLabourCharge,
    required this.hourlyRate,
    required this.estimatedLabourHours,
  });

  //  : estimatedLabourHours =
  //          hourlyRate == MoneyEx.zero
  //              ? Fixed.zero
  //              : estimatedLabourCharge.divideByFixed(hourlyRate.amount).amount;

  Task task;
  Money hourlyRate;

  /// Estimated material charges taken from
  /// [CheckListItem]s materials buy
  Money estimatedMaterialsCharge;

  /// Estimated labour (in hours) for the task taken
  /// from [CheckListItem]s of type [TaskItemType.labour]
  Money estimatedLabourCharge;

  Fixed estimatedLabourHours;

  /// Total charges including the margin.
  Money get total => estimatedMaterialsCharge + estimatedLabourCharge;
}
