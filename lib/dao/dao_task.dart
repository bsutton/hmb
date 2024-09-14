import 'package:dcli_core/dcli_core.dart';
import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/check_list_item.dart';
import '../entity/job.dart';
import '../entity/task.dart';
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

  Future<TaskStatistics> getTaskStatistics(Task task) async {
    var totalEffort = Fixed.zero;
    var completedEffort = Fixed.zero;
    final totalCost = MoneyEx.zero;
    var earnedCost = MoneyEx.zero;

    final hourlyRate = await DaoTask().getHourlyRate(task);

    // Get task cost and effort using the new getTaskCost method
    final taskCost = await getTaskEstimates(task, hourlyRate);

    // Total effort and cost are retrieved directly from the taskCost
    totalEffort = taskCost.effortInHours;
    completedEffort += taskCost.effortInHours;
    earnedCost += taskCost.earnedCost;

    final timeEntries = await DaoTimeEntry().getByTask(task.id);

    var trackedEffort = Duration.zero;

    for (final timeEntry in timeEntries) {
      trackedEffort += timeEntry.duration;
    }

    return TaskStatistics(
        totalEffort: totalEffort,
        completedEffort: completedEffort,
        totalCost: totalCost,
        earnedCost: earnedCost,
        trackedEffort: trackedEffort);
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

  Future<TaskEstimates> getTaskEstimates(Task task, Money hourlyRate) async {
    var totalCost = MoneyEx.zero;
    var totalEffortInHours = Fixed.zero;
    var completedEffort = Fixed.zero;
    var earnedCost = MoneyEx.zero;

    // Get checklist items for the task
    final checkListItems = await DaoCheckListItem().getByTask(task.id);

    for (final item in checkListItems) {
      if (item.itemTypeId == 5) {
        // Action type checklist item (effort)
        totalEffortInHours += item.estimatedLabour!;
        if (item.completed) {
          completedEffort += item.estimatedLabour!; // Sum up completed effort
          earnedCost += item.estimatedMaterialCost!.multiplyByFixed(
              item.estimatedMaterialQuantity!); // Sum up earned cost
        }
      } else if (item.itemTypeId == 1 || item.itemTypeId == 3) {
        // Materials and tools to be purchased
        totalCost += item.estimatedMaterialCost!
            .multiplyByFixed(item.estimatedMaterialQuantity!);
        if (item.completed) {
          earnedCost += item.estimatedMaterialCost!.multiplyByFixed(item
              .estimatedMaterialQuantity!); // Earned cost for completed items
        }
      }
    }

    // Calculate time entries cost
    final timeEntries = await DaoTimeEntry().getByTask(task.id);
    for (final entry in timeEntries.where((entry) => !entry.billed)) {
      final duration = entry.duration.inMinutes / 60;
      totalCost += hourlyRate.multiplyByFixed(Fixed.fromNum(duration));
    }

    return TaskEstimates(
        task: task,
        cost: totalCost,
        effortInHours: totalEffortInHours,
        completedEffort: completedEffort,
        earnedCost: earnedCost);
  }

  /// Returns a list of Task with their associated costs.
  Future<List<TaskEstimates>> getTaskCostsByJob(
      int jobId, Money hourlyRate) async {
    final tasks = await getTasksByJob(jobId);
    final taskCosts = <TaskEstimates>[];

    for (final task in tasks) {
      // Use the new getTaskCost method which now includes effortInHours
      final taskCost = await getTaskEstimates(task, hourlyRate);
      taskCosts.add(taskCost);
    }

    return taskCosts;
  }

  Future<Money> getTimeAndMaterialEarnings(Task task, Money hourlyRate) async {
    assert(task.billingType == BillingType.timeAndMaterial,
        'Can only be called for tasks billed by TimeAndMaterials');
    var totalCost = MoneyEx.zero;

    // Get all time entries for the task
    final timeEntries = await DaoTimeEntry().getByTask(task.id);
    for (final entry in timeEntries.where((entry) => !entry.billed)) {
      final duration = entry.duration.inMinutes / 60;
      totalCost += hourlyRate.multiplyByFixed(Fixed.fromNum(duration));
    }

    // Get all checklist items for the task
    final checkListItems = await DaoCheckListItem().getByTask(task.id);
    for (final item in checkListItems.where((item) => !item.billed)) {
      totalCost += item.estimatedMaterialCost!
          .multiplyByFixed(item.estimatedMaterialQuantity!);
    }

    return totalCost;
  }

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
}

/// Used to notify the UI that the time entry has changed.
class TaskState extends JuneState {
  TaskState();
}

class TaskStatistics {
  TaskStatistics(
      {required this.totalEffort,
      required this.completedEffort,
      required this.totalCost,
      required this.earnedCost,
      required this.trackedEffort});
  final Fixed totalEffort;
  final Fixed completedEffort;
  final Money totalCost;
  final Money earnedCost;

  /// sum of TimeEntry's for this task.
  Duration trackedEffort;
}

class TaskEstimates {
  TaskEstimates({
    required this.task,
    required this.cost,
    required this.effortInHours,
    required this.completedEffort,
    required this.earnedCost,
  });

  Task task;
  Money cost;
  Fixed effortInHours; // Total effort for the task
  Fixed completedEffort; // Effort from completed checklist items
  Money earnedCost; // Cost from completed checklist items
}
