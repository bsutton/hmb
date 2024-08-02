import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';
import 'package:strings/strings.dart';

import '../entity/customer.dart';
import '../entity/job.dart';
import '../entity/task.dart';
import '../util/fixed_ex.dart';
import '../util/money_ex.dart';
import 'dao.dart';
import 'dao_checklist_item.dart';
import 'dao_invoice.dart';
import 'dao_quote.dart';
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

  Future<Job> getJobForTask(Task task) async {
    final db = getDb();

    final data = await db.rawQuery('''
select j.* 
from task t
join job j
  on t.jobId = j.id
where t.id =?
''', [task.id]);

    return toList(data).first;
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
      final status = await DaoTaskStatus().getById(task.taskStatusId);

      if (status?.isComplete() ?? false) {
        completedEffort += task.effortInHours ?? FixedEx.zero;
        earnedCost += task.estimatedCost ?? MoneyEx.zero;
        completedTasks++;
      }
      totalEffort += task.effortInHours ?? FixedEx.zero;
      totalCost += task.estimatedCost ?? MoneyEx.zero;

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
    final tasks = await DaoTask().getTasksByJob(job.id);
    for (final task in tasks) {
      final timeEntries = await DaoTimeEntry().getByTask(task.id);
      final unbilledTimeEntries = timeEntries.where((entry) => !entry.billed);
      if (unbilledTimeEntries.isNotEmpty) {
        return true;
      }

      final checkListItems = await DaoCheckListItem().getByTask(task);
      final unbilledCheckListItems =
          checkListItems.where((item) => !item.billed && item.hasCost);
      if (unbilledCheckListItems.isNotEmpty) {
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
      if (task.effortInHours != null || task.estimatedCost != null) {
        return true;
      }
    }
    return false;
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
