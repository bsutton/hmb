/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:strings/strings.dart';

import '../entity/customer.dart';
import '../entity/job.dart';
import '../entity/job_status.dart';
import '../entity/job_status_stage.dart';
import '../entity/task.dart';
import '../entity/task_item.dart';
import '../entity/task_item_type.dart';
import '../util/dart/exceptions.dart';
import '../util/dart/money_ex.dart';
import 'dao.dart';
import 'dao_contact.dart';
import 'dao_customer.dart';
import 'dao_invoice.dart';
import 'dao_quote.dart';
import 'dao_system.dart';
import 'dao_task.dart';
import 'dao_task_item.dart';
import 'dao_time_entry.dart';
import 'dao_todo.dart';
import 'dao_work_assignment_task.dart';

enum JobOrder {
  active('Most Recently Accessed'),
  created('Oldest Jobs first'),
  recent('Newest Jobs First');

  const JobOrder(this.description);
  final String description;
}

class DaoJob extends Dao<Job> {
  static const tableName = 'job';

  DaoJob() : super(tableName);

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
  Job fromMap(Map<String, dynamic> map) => Job.fromMap(map);

  @override
  Future<int> update(Job entity, [Transaction? transaction]) async {
    final existing = await getById(entity.id);
    final isRejectingJob =
        existing != null &&
        existing.status != entity.status &&
        entity.status == JobStatus.rejected;
    final isCompletingJob =
        existing != null &&
        existing.status != entity.status &&
        entity.status == JobStatus.completed;

    if (!isRejectingJob && !isCompletingJob) {
      return super.update(entity, transaction);
    }

    if (transaction != null) {
      if (isRejectingJob) {
        await DaoQuote().rejectByJob(entity.id, transaction: transaction);
      }
      if (isCompletingJob) {
        await DaoToDo().markDoneByJob(entity.id, transaction: transaction);
      }
      return super.update(entity, transaction);
    }

    return db.transaction((txn) async {
      if (isRejectingJob) {
        await DaoQuote().rejectByJob(entity.id, transaction: txn);
      }
      if (isCompletingJob) {
        await DaoToDo().markDoneByJob(entity.id, transaction: txn);
      }
      return super.update(entity, txn);
    });
  }

  /// getAll - sort by modified date descending
  @override
  Future<List<Job>> getAll({
    String? orderByClause,
    Transaction? transaction,
  }) async {
    final db = withinTransaction(transaction);
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
    return getFirstOrNull(data);
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

    if (job.status.stage == JobStatusStage.preStart) {
      job.status = JobStatus.inProgress;
    }
    await update(job);

    return job;
  }

  /// Marks the job as 'in quoting' if it is
  /// in a [JobStatus.prospecting] state.
  Future<Job> markQuoting(int jobId) async {
    final job = await getById(jobId);

    /// even if the job is active we want to update the last
    /// modified date so it comes up first in the job list.
    job!.lastActive = true;
    job.modifiedDate = DateTime.now();

    if (job.status == JobStatus.prospecting) {
      job.status = JobStatus.quoting;
    }
    await update(job);

    return job;
  }

  /// search for jobs given a user supplied filter string.
  Future<List<Job>> getByFilter(
    String? filter, {
    JobOrder order = JobOrder.active,
  }) async {
    final db = withoutTransaction();

    final args = <String>[];
    var whereClause = '';
    if (Strings.isNotBlank(filter)) {
      final likeArg = '''%$filter%''';
      whereClause = '''
where j.summary like ?
or j.description like ?
or coalesce(c.name, '') like ?''';

      args.addAll([likeArg, likeArg, likeArg]);
    }

    final String orderByColumn;
    var sort = 'desc';

    switch (order) {
      case JobOrder.active:
        orderByColumn = 'j.modified_date';
      case JobOrder.created:
        orderByColumn = 'j.created_date';
        sort = 'asc';
      case JobOrder.recent:
        orderByColumn = 'j.created_date';
        sort = 'desc';
    }

    return toList(
      await db.rawQuery('''
select j.*
from job j
left join customer c
  on c.id = j.customer_id
$whereClause
order by $orderByColumn $sort
''', args),
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

    return getFirstOrNull(data);
  }

  /// Only Jobs that we consider to be active, filtered by
  /// (summary | description | customer.name), case-insensitive.
  Future<List<Job>> getActiveJobs(String? filter) async {
    final db = withoutTransaction();
    final likeArg = (filter != null && filter.isNotEmpty) ? '%$filter%' : '%%';

    return toList(
      await db.rawQuery(
        '''
      SELECT j.*
      FROM job j
      LEFT JOIN customer c
        ON c.id = j.customer_id
      WHERE j.status_id NOT IN (
        '${JobStatus.rejected.id}',
        '${JobStatus.onHold.id}',
        '${JobStatus.awaitingPayment.id}',
        '${JobStatus.completed.id}',
        '${JobStatus.toBeBilled.id}'
      )
      AND (
        j.summary LIKE ? COLLATE NOCASE
        OR j.description LIKE ? COLLATE NOCASE
        OR COALESCE(c.name, '') LIKE ? COLLATE NOCASE
      )
      ORDER BY j.modified_date DESC
      ''',
        [likeArg, likeArg, likeArg],
      ),
    );
  }

  Future<List<Job>> getSchedulableJobs(String? filter) async {
    final db = withoutTransaction();
    final likeArg = filter != null ? '''%$filter%''' : '%%';

    final canBeScheduled = JobStatus.canBeScheduled().map(
      (status) => status.id,
    );

    final canBeScheduledPlaceHolders = List.filled(
      canBeScheduled.length,
      '?',
    ).join(',');

    return toList(
      await db.rawQuery(
        '''
    SELECT j.*
    FROM job j
    WHERE j.status_id IN ( $canBeScheduledPlaceHolders )
    AND (j.summary LIKE ? OR j.description LIKE ?)
    ORDER BY j.modified_date DESC
    ''',
        [...canBeScheduled, likeArg, likeArg],
      ),
    );
  }

  Future<void> markAwaitingApproval(Job job) async {
    final canBeApproved = JobStatus.canBeAwaitingApproved(job);

    if (canBeApproved) {
      job.status = JobStatus.awaitingApproval;
      await DaoJob().update(job);
    }
  }

  /// Mark the job as scheduled if it is in a pre-start state.
  Future<void> markScheduled(Job job) async {
    final jobStatus = job.status;

    if (jobStatus.stage == JobStatusStage.preStart) {
      job.status = JobStatus.scheduled;
      await DaoJob().update(job);
    }
  }

  /// Get Quotable Jobs - now filtered by `preStart` status
  Future<List<Job>> getQuotableJobs(String? filter) async {
    final db = withoutTransaction();
    final likeArg = filter != null ? '%$filter%' : '%%';

    final preStartList =
        ''' '${JobStatus.preStart().map((status) => status.id).join("', '")}' ''';

    return toList(
      await db.rawQuery(
        '''
    SELECT j.*
    FROM job j
    WHERE j.status_id in ($preStartList)
    AND (j.summary LIKE ? OR j.description LIKE ?)
    ORDER BY j.modified_date DESC
  ''',
        [likeArg, likeArg],
      ),
    );
  }

  /// Get all jobs with any of the given [statuses].
  Future<List<Job>> getByStatuses(List<JobStatus> statuses) async {
    if (statuses.isEmpty) {
      return [];
    }

    final db = withoutTransaction();
    final placeholders = List.filled(statuses.length, '?').join(',');

    return toList(
      await db.query(
        tableName,
        where: 'status_id IN ($placeholders)',
        whereArgs: statuses.map((s) => s.id).toList(),
        orderBy: 'modified_date DESC',
      ),
    );
  }

  Future<JobStatistics> getJobStatistics(Job job) async {
    final tasks = await DaoTask().getTasksByJob(job.id);

    final hourlyRate = await DaoJob().getHourlyRate(job.id);

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
        var hours = Fixed.zero;
        var materialCost = MoneyEx.zero;
        switch (item.itemType) {
          case TaskItemType.materialsBuy:
          case TaskItemType.materialsStock:
          case TaskItemType.consumablesStock:
          case TaskItemType.consumablesBuy:
            materialCost = item.estimatedMaterialUnitCost!.multiplyByFixed(
              item.estimatedMaterialQuantity!,
            );

          case TaskItemType.toolsBuy:
          case TaskItemType.toolsOwn:
            materialCost = MoneyEx.zero;
          case TaskItemType.labour:
            switch (item.labourEntryMode) {
              case LabourEntryMode.hours:
                hours = item.estimatedLabourHours!;
              case LabourEntryMode.dollars:
                hours = Fixed.fromNum(
                  item.estimatedLabourCost!.dividedBy(hourlyRate),
                );
            }
        }

        expectedLabourHours += hours;
        totalMaterialCost += materialCost;

        // If the task is completed, add to completed effort and earned cost
        if ((status.isComplete()) || item.completed) {
          completedLabourHours += hours;
          completedMaterialCost += materialCost;
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

  Future<Job?> getByQuoteId(int quoteId) async {
    final db = withoutTransaction();

    return getFirstOrNull(
      await db.rawQuery(
        '''
select j.* 
from quote q
join job j
  on q.job_id = j.id
where q.id=?
''',
        [quoteId],
      ),
    );
  }

  Future<bool> hasBillableTasks(Job job) async {
    final tasksAccruedValue = await DaoTask().getAccruedValueForJob(
      job: job,
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
      bestEmail = (await DaoContact().getPrimaryForJob(job.id))?.bestEmail;
    }

    if (bestEmail == null) {
      final customer = await DaoCustomer().getByJob(job.id);
      bestEmail = (await DaoContact().getPrimaryForCustomer(
        customer!.id,
      ))?.bestEmail;
    }
    return bestEmail;
  }

  Future<List<String>> getEmailsByJob(int jobId) async {
    final job = await DaoJob().getById(jobId);
    final customer = await DaoCustomer().getById(job!.customerId);
    final contacts = await DaoContact().getByCustomer(customer!.id);

    /// make sure we have no dups.
    final emails = <String>{};

    for (final contact in contacts) {
      if (Strings.isNotBlank(contact.emailAddress)) {
        emails.add(contact.emailAddress.trim());
      }
      if (Strings.isNotBlank(contact.alternateEmail)) {
        emails.add(contact.alternateEmail!.trim());
      }
    }

    return emails.toList();
  }

  Future<bool> hasQuoteableItems(Job job) async {
    final estimates = await DaoTask().getEstimatesForJob(job);

    return estimates.fold(false, (a, b) async => await a || b.total.isPositive);
  }

  Future<Money> getHourlyRate(int jobId) async {
    final job = await getById(jobId);

    return job?.hourlyRate ?? DaoSystem().getHourlyRate();
  }

  /// Calculates the total quoted price for the job.
  Future<Money> getFixedPriceTotal(Job job) async {
    final estimates = await DaoTask().getEstimatesForJob(job);

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
      if (job.billingType == BillingType.nonBillable) {
        continue;
      }
      if (await DaoJob().hasBillableTasks(job)) {
        ready.add(job);
      }
    }
    return ready;
  }

  /// Copy a [Job] and move selected [Task]s to the new [Job]
  Future<Job> copyJobAndMoveTasks({
    required Job job,
    required List<Task> tasksToMove,
    required String summary,
    JobStatus? newJobStatus,
    Transaction? transaction,
  }) async {
    final daoTask = DaoTask();
    final daoTaskItem = DaoTaskItem();
    final daoTimeEntry = DaoTimeEntry();
    final daoWAT = DaoWorkAssignmentTask();

    // Validate [Task]s belong to the [Job]
    for (final task in tasksToMove) {
      if (task.jobId != job.id) {
        throw TaskMoveException(
          'Task ${task.name} does not belong to job ${job.description}.',
        );
      }
    }

    // Preload approved quotes (only if Fixed Price)
    // Check business rules
    final nonMovableReasons = <Task, String>{};
    for (final t in tasksToMove) {
      final billed = await daoTask.isTaskBilled(
        task: t,
        daoTaskItem: daoTaskItem,
        daoTimeEntry: daoTimeEntry,
      );
      if (billed) {
        nonMovableReasons[t] = 'has billed items or time.';
        continue;
      }
      final hasWA = await daoTask.hasWorkAssignment(task: t, daoWAT: daoWAT);
      if (hasWA) {
        nonMovableReasons[t] = 'is linked to a work assignment.';
        continue;
      }

      if (await daoTask.isTaskLinkedToQuote(t)) {
        nonMovableReasons[t] = 'is linked to a quote.';
        continue;
      }
    }

    if (nonMovableReasons.isNotEmpty) {
      final b = StringBuffer('One or more tasks cannot be moved:\n');
      nonMovableReasons.forEach((id, why) {
        b.writeln(' - Task $id: $why');
      });
      throw TaskMoveException(b.toString());
    }

    // Use withinTransaction so everything is atomic
    return withTransaction((transaction) async {
      // 1. Insert new job
      final inserted = Job.forInsert(
        customerId: job.customerId,
        summary: summary,
        description: job.description,
        assumption: job.assumption,
        siteId: job.siteId,
        contactId: job.contactId,
        status: newJobStatus ?? JobStatus.startingStatus,
        hourlyRate: job.hourlyRate,
        bookingFee: job.bookingFee,
        billingContactId: job.billingContactId,
        billingType: job.billingType,
        lastActive: true,
      );

      final newJobId = await insert(inserted, transaction);
      final newJob = (await getById(newJobId, transaction))!;

      // 2. Move tasks by updating jobId
      for (final t in tasksToMove) {
        final moved = t.copyWith(
          jobId: newJobId,
          name: t.name,
          description: t.description,
          assumption: t.assumption,
          status: t.status,
        );
        await daoTask.update(moved, transaction);
      }

      final srcTouched = job
        ..modifiedDate = DateTime.now()
        ..lastActive = false;
      await update(srcTouched, transaction);

      return newJob;
    });
  }
}

class JobStatistics {
  final int totalTasks;
  final int completedTasks;
  final Fixed expectedLabourHours;
  final Fixed completedLabourHours;
  final Money totalMaterialCost;
  final Money completedMaterialCost;
  final Money worked;
  final Fixed workedHours;

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
}
