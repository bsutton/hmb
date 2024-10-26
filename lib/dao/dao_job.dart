import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';
import 'package:strings/strings.dart';

import '../entity/customer.dart';
import '../entity/job.dart';
import '../util/money_ex.dart';
import 'dao.dart';
import 'dao_checklist_item.dart';
import 'dao_invoice.dart';
import 'dao_quote.dart';
import 'dao_system.dart';
import 'dao_task.dart';
import 'dao_task_status.dart';
import 'dao_time_entry.dart';

class DaoJob extends Dao<Job> {
  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    final db = getDb(transaction);

    await DaoTask().deleteByJob(id, transaction: transaction);
    await DaoInvoice().deleteByJob(id, transaction: transaction);
    await DaoQuote().deleteByJob(id, transaction: transaction);

    // Delete the job itself
    return db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  String get tableName => 'job';

  @override
  Job fromMap(Map<String, dynamic> map) => Job.fromMap(map);

  /// getAll - sort by modified date descending
  @override
  Future<List<Job>> getAll(
      {String? orderByClause, Transaction? transaction}) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps =
        await db.query(tableName, orderBy: 'modifiedDate desc');
    final list = List.generate(maps.length, (i) => fromMap(maps[i]));

    return list;
  }

  Future<Job?> getLastActiveJob() async {
    final db = getDb();
    final data = await db.query(
      tableName,
      where: 'last_active = ?',
      whereArgs: [1],
      orderBy: 'modifiedDate desc',
      limit: 1,
    );
    return data.isNotEmpty ? fromMap(data.first) : null;
  }

  Future<void> markActive(int jobId) async {
    final lastActive = await getLastActiveJob();
    if (lastActive != null) {
      if (lastActive.id != jobId) {
        lastActive.lastActive = false;
        await update(lastActive);
      }
    }
    final job = await getById(jobId);

    /// even if the job is active we want to update the last
    /// modified date so it comes up first in the job list.
    job?.lastActive = true;
    job?.modifiedDate = DateTime.now();
    await update(job!);
  }

  /// search for jobs given a user supplied filter string.
  Future<List<Job>> getByFilter(String? filter) async {
    final db = getDb();

    if (Strings.isBlank(filter)) {
      return getAll();
    }

    final likeArg = '''%$filter%''';
    final data = await db.rawQuery('''
select j.*
from job j
join customer c
  on c.id = j.customer_id
join job_status js
  on j.job_status_id = js.id
where j.summary like ?
or j.description like ?
or c.name like ?
or js.name like ?
order by j.modifiedDate desc
''', [likeArg, likeArg, likeArg, likeArg]);

    return toList(data);
  }

  Future<Job?> getJobForTask(int? taskId) async {
    final db = getDb();

    if (taskId == null) {
      return null;
    }

    final data = await db.rawQuery('''
select j.* 
from task t
join job j
  on t.job_id = j.id
where t.id =?
''', [taskId]);

    return toList(data).first;
  }

  /// Only Jobs that we consider to be active.
  Future<List<Job>> getActiveJobs(String? filter) async {
    final db = getDb();
    final likeArg = filter != null ? '''%$filter%''' : '%%';

    final data = await db.rawQuery('''
    SELECT j.*
    FROM job j
    JOIN job_status js ON j.job_status_id = js.id
    WHERE js.name NOT IN ('Prospecting', 'Rejected', 'On Hold', 'Awaiting Payment', 'Completed', 'To be Billed')
    AND (j.summary LIKE ? OR j.description LIKE ?)
    ORDER BY j.modifiedDate DESC
    ''', [likeArg, likeArg]);

    return toList(data);
  }

  Future<JobStatistics> getJobStatistics(Job job) async {
    final tasks = await DaoTask().getTasksByJob(job.id);

    final totalTasks = tasks.length;
    var completedTasks = 0;
    var totalEffort = Fixed.zero;
    var completedEffort = Fixed.zero;
    var totalCost = MoneyEx.zero;
    var earnedCost = MoneyEx.zero;
    var workedHours = Fixed.fromNum(0, scale: 2);

    for (final task in tasks) {
      // Fetch task status to check if it's completed
      final status = await DaoTaskStatus().getById(task.taskStatusId);

      // Fetch checklist items related to the task
      final checkListItems = await DaoCheckListItem().getByTask(task.id);

      // Calculate effort and cost from checklist items
      for (final item in checkListItems) {
        totalEffort += item.estimatedLabourHours!;
        totalCost += item.estimatedMaterialUnitCost!
            .multiplyByFixed(item.estimatedMaterialQuantity!);

        // If the task is completed, add to completed effort and earned cost
        if ((status?.isComplete() ?? false) && item.completed) {
          completedEffort += item.estimatedLabourHours!;
          earnedCost += item.estimatedMaterialUnitCost!
              .multiplyByFixed(item.estimatedMaterialQuantity!);
        }
      }

      if (status?.isComplete() ?? false) {
        completedTasks++;
      }

      // Calculate worked hours from time entries
      final timeEntries = await DaoTimeEntry().getByTask(task.id);
      for (final timeEntry in timeEntries) {
        workedHours +=
            Fixed.fromInt((timeEntry.duration.inMinutes / 60.0 * 100).toInt());
      }
    }

    return JobStatistics(
        totalTasks: totalTasks,
        completedTasks: completedTasks,
        totalEffort: totalEffort,
        completedEffort: completedEffort,
        totalCost: totalCost,
        earnedCost: earnedCost,
        workedHours: workedHours,
        worked: job.hourlyRate!.multiplyByFixed(workedHours));
  }

  Future<Money> getBookingFee(Job job) async {
    if (job.bookingFee != null) {
      return job.bookingFee!;
    }

    final system = await DaoSystem().get();

    if (system != null && system.defaultBookingFee != null) {
      return system.defaultBookingFee!;
    }

    return MoneyEx.zero;
  }

  /// Get all the jobs for the given customer.
  Future<List<Job>> getByCustomer(Customer customer) async {
    final db = getDb();

    final data = await db.rawQuery('''
select j.* 
from job j
join customer c
  on j.customer_id = c.id
where c.id =?
''', [customer.id]);

    return toList(data);
  }

  Future<bool> hasBillableTasks(Job job) async {
    final tasksAccruedValue =
        await DaoTask().getTaskCostsByJob(jobId: job.id, includeBilled: false);

    for (final task in tasksAccruedValue) {
      if ((await task.earned) > MoneyEx.zero) {
        return true;
      }
    }

    return false;
  }

  @override
  JuneStateCreator get juneRefresher => JobState.new;

  Future<bool> hasQuoteableItems(Job job) async {
    if (await hasBillableTasks(job)) {
      return true;
    }
    final tasks = await DaoTask().getTasksByJob(job.id);
    for (final task in tasks) {
      final items = await DaoCheckListItem().getByTask(task.id);

      for (final item in items) {
        if (item.estimatedLabourHours != null ||
            item.estimatedLabourCost != null) {
          return true;
        }
      }
    }
    return false;
  }

  Future<Money> getHourlyRate(int jobId) async {
    final job = await getById(jobId);

    return job?.hourlyRate ?? DaoSystem().getHourlyRate();
  }
}

/// Used to notify the UI that the time entry has changed.
class JobState extends JuneState {
  JobState();
}

class JobStatistics {
  JobStatistics({
    required this.totalTasks,
    required this.completedTasks,
    required this.totalEffort,
    required this.completedEffort,
    required this.totalCost,
    required this.earnedCost,
    required this.worked,
    required this.workedHours,
  });
  final int totalTasks;
  final int completedTasks;
  final Fixed totalEffort;
  final Fixed completedEffort;
  final Money totalCost;
  final Money earnedCost;
  final Money worked;
  final Fixed workedHours;
}
