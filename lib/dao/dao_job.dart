/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';
import 'package:strings/strings.dart';

import '../entity/customer.dart';
import '../entity/job.dart';
import '../entity/job_status_enum.dart';
import '../util/money_ex.dart';
import 'dao.g.dart';

class DaoJob extends Dao<Job> {
  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);

    await DaoTask().deleteByJob(id, transaction: transaction);
    await DaoInvoice().deleteByJob(id, transaction: transaction);
    await DaoQuote().deleteByJob(id, transaction: transaction);

    // Delete the job itself
    return db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  String get tableName => 'job';

  @override
  Job fromMap(Map<String, dynamic> map) => Job.fromMap(map);

  /// getAll - sort by modified date descending
  @override
  Future<List<Job>> getAll({String? orderByClause}) async {
    final db = withoutTransaction();
    return toList(await db.query(tableName, orderBy: 'modified_date desc'));
  }

  Future<Job?> getLastActiveJob() async {
    final db = withoutTransaction();
    final data = await db.query(
      tableName,
      where: 'last_active = ?',
      whereArgs: [1],
      orderBy: 'modified_date desc',
      limit: 1,
    );
    return data.isNotEmpty ? fromMap(data.first) : null;
  }

  /// Marks the job as 'in progress' if it is
  /// in a pre-start state.
  /// Also marks the job as the last active job.
  Future<Job> markActive(int jobId) async {
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
    job!.lastActive = true;
    job.modifiedDate = DateTime.now();

    final jobStatus = await DaoJobStatus().getById(job.jobStatusId);
    if (jobStatus!.statusEnum == JobStatusEnum.preStart) {
      final inProgress = await DaoJobStatus().getInProgress();

      job.jobStatusId = inProgress!.id;
    }
    await update(job);

    return job;
  }

  /// Marks the job as 'in quoting' if it is
  /// in a pre-start state.
  Future<Job> markQuoting(int jobId) async {
    final job = await getById(jobId);

    /// even if the job is active we want to update the last
    /// modified date so it comes up first in the job list.
    job!.lastActive = true;
    job.modifiedDate = DateTime.now();

    final jobStatus = await DaoJobStatus().getById(job.jobStatusId);
    if (jobStatus!.statusEnum == JobStatusEnum.preStart) {
      final quoting = await DaoJobStatus().getQuoting();

      job.jobStatusId = quoting!.id;
    }
    await update(job);

    return job;
  }

  /// search for jobs given a user supplied filter string.
  Future<List<Job>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    if (Strings.isBlank(filter)) {
      return getAll();
    }

    final likeArg = '''%$filter%''';
    return toList(
      await db.rawQuery(
        '''
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
order by j.modified_date desc
''',
        [likeArg, likeArg, likeArg, likeArg],
      ),
    );
  }

  Future<Job?> getJobForTask(int? taskId) async {
    final db = withoutTransaction();

    if (taskId == null) {
      return null;
    }

    final data = await db.rawQuery(
      '''
select j.* 
from task t
join job j
  on t.job_id = j.id
where t.id =?
''',
      [taskId],
    );

    return toList(data).first;
  }

  /// Only Jobs that we consider to be active.
  Future<List<Job>> getActiveJobs(String? filter) async {
    final db = withoutTransaction();
    final likeArg = filter != null ? '''%$filter%''' : '%%';

    return toList(
      await db.rawQuery(
        '''
    SELECT j.*
    FROM job j
    JOIN job_status js ON j.job_status_id = js.id
    WHERE js.name NOT IN ( 'Rejected', 'On Hold', 'Awaiting Payment', 'Completed', 'To be Billed')
    AND (j.summary LIKE ? OR j.description LIKE ?)
    ORDER BY j.modified_date DESC
    ''',
        [likeArg, likeArg],
      ),
    );
  }

  /// Get Quotable Jobs - now filtered by `preStart` status
  Future<List<Job>> getQuotableJobs(String? filter) async {
    final db = withoutTransaction();
    final likeArg = filter != null ? '%$filter%' : '%%';

    // Use the enum's name property to match the `status_enum` column in the database
    final preStartStatus = JobStatusEnum.preStart.name;

    return toList(
      await db.rawQuery(
        '''
    SELECT j.*
    FROM job j
    JOIN job_status js ON j.job_status_id = js.id
    WHERE js.status_enum = ?
    AND (j.summary LIKE ? OR j.description LIKE ?)
    ORDER BY j.modified_date DESC
  ''',
        [preStartStatus, likeArg, likeArg],
      ),
    );
  }

  Future<JobStatistics> getJobStatistics(Job job) async {
    final tasks = await DaoTask().getTasksByJob(job.id);

    final totalTasks = tasks.length;
    var completedTasks = 0;
    var expectedLabourHours = Fixed.zero;
    var completedLabourHours = Fixed.zero;
    var totalMaterialCost = MoneyEx.zero;
    var completedMaterialCost = MoneyEx.zero;
    var workedHours = Fixed.fromNum(0, decimalDigits: 2);

    for (final task in tasks) {
      // Fetch task status to check if it's completed
      final status = task.status;

      // Fetch checklist items related to the task
      final taskItems = await DaoTaskItem().getByTask(task.id);

      // Calculate effort and cost from checklist items
      for (final item in taskItems) {
        expectedLabourHours += item.estimatedLabourHours!;
        totalMaterialCost += item.estimatedMaterialUnitCost!.multiplyByFixed(
          item.estimatedMaterialQuantity!,
        );

        // If the task is completed, add to completed effort and earned cost
        if ((status.isComplete()) || item.completed) {
          completedLabourHours += item.estimatedLabourHours!;
          completedMaterialCost += item.estimatedMaterialUnitCost!
              .multiplyByFixed(item.estimatedMaterialQuantity!);
        }
      }

      if (status.isComplete()) {
        completedTasks++;
      }

      // Calculate worked hours from time entries
      final timeEntries = await DaoTimeEntry().getByTask(task.id);
      for (final timeEntry in timeEntries) {
        workedHours += Fixed.fromInt(
          (timeEntry.duration.inMinutes / 60.0 * 100).toInt(),
        );
      }
    }

    return JobStatistics(
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      expectedLabourHours: expectedLabourHours,
      completedLabourHours: completedLabourHours,
      totalMaterialCost: totalMaterialCost,
      completedMaterialCost: completedMaterialCost,
      workedHours: workedHours,
      worked: job.hourlyRate!.multiplyByFixed(workedHours),
    );
  }

  Future<Money> getBookingFee(Job job) async {
    if (job.bookingFee != null) {
      return job.bookingFee!;
    }

    final system = await DaoSystem().get();

    if (system.defaultBookingFee != null) {
      return system.defaultBookingFee!;
    }

    return MoneyEx.zero;
  }

  /// Get all the jobs for the given customer.
  Future<List<Job>> getByCustomer(Customer? customer) async {
    if (customer == null) {
      return [];
    }
    final db = withoutTransaction();

    return toList(
      await db.rawQuery(
        '''
select j.* 
from job j
join customer c
  on j.customer_id = c.id
where c.id =?
''',
        [customer.id],
      ),
    );
  }

  Future<bool> hasBillableTasks(Job job) async {
    final tasksAccruedValue = await DaoTask().getAccruedValueForJob(
      jobId: job.id,
      includedBilled: false,
    );

    for (final task in tasksAccruedValue) {
      if ((await task.earned) > MoneyEx.zero) {
        return true;
      }
    }

    return false;
  }

  Future<String?> getBestPhoneNumber(Job job) async {
    String? bestPhone;
    if (job.contactId != null) {
      bestPhone = (await DaoContact().getPrimaryForJob(job.id))?.bestPhone;
    }

    if (bestPhone == null) {
      final customer = await DaoCustomer().getByJob(job.id);
      bestPhone = (await DaoContact().getPrimaryForCustomer(
        customer!.id,
      ))?.bestPhone;
    }
    return bestPhone;
  }

  Future<String?> getBestEmail(Job job) async {
    String? bestEmail;
    if (job.contactId != null) {
      bestEmail = (await DaoContact().getPrimaryForJob(job.id))?.emailAddress;
    }

    if (bestEmail == null) {
      final customer = await DaoCustomer().getByJob(job.id);
      bestEmail = (await DaoContact().getPrimaryForCustomer(
        customer!.id,
      ))?.emailAddress;
    }
    return bestEmail;
  }

  @override
  JuneStateCreator get juneRefresher => JobState.new;

  Future<bool> hasQuoteableItems(Job job) async {
    final estimates = await DaoTask().getEstimatesForJob(job.id);

    return estimates.fold(false, (a, b) async => await a || b.total.isPositive);
  }

  Future<Money> getHourlyRate(int jobId) async {
    final job = await getById(jobId);

    return job?.hourlyRate ?? DaoSystem().getHourlyRate();
  }

  /// Calculates the total quoted price for the job.
  Future<Money> getFixedPriceTotal(Job job) async {
    final estimates = await DaoTask().getEstimatesForJob(job.id);

    var total = MoneyEx.zero;
    for (final estimate in estimates) {
      if (estimate.total > MoneyEx.zero) {
        total += estimate.total;
      }
    }
    return total;
  }

  /// Must be
  /// Time and Materials
  /// Not been invoiced
  /// Have a non-zero booking fee.
  Future<bool> hasBillableBookingFee(Job job) async =>
      job.billingType == BillingType.timeAndMaterial &&
      !job.bookingFeeInvoiced &&
      job.bookingFee != null &&
      (await getBookingFee(job) != MoneyEx.zero);

  Future<void> markBookingFeeNotBilled(Job job) async {
    job.bookingFeeInvoiced = false;

    await update(job);
  }

  Future<Job> getJobForInvoice(int invoiceId) async {
    final invoice = await DaoInvoice().getById(invoiceId);
    return (await getById(invoice!.jobId))!;
  }

  Future<Job> getJobForQuote(int quoteId) async {
    final quote = await DaoQuote().getById(quoteId);
    return (await getById(quote!.jobId))!;
  }

  Future<List<Job>> readyToBeInvoiced(String? filter) async {
    final activeJobs = await DaoJob().getActiveJobs(filter);
    final ready = <Job>[];
    for (final job in activeJobs) {
      if (await DaoJob().hasBillableTasks(job)) {
        ready.add(job);
      }
    }
    return ready;
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
    required this.expectedLabourHours,
    required this.completedLabourHours,
    required this.totalMaterialCost,
    required this.completedMaterialCost,
    required this.worked,
    required this.workedHours,
  });
  final int totalTasks;
  final int completedTasks;
  final Fixed expectedLabourHours;
  final Fixed completedLabourHours;
  final Money totalMaterialCost;
  final Money completedMaterialCost;
  final Money worked;
  final Fixed workedHours;
}
