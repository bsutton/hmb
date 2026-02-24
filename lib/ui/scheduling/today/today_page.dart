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

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';

// -- Example imports. Adapt for your project:
import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/flutter/flutter_util.g.dart';
import '../../crud/todo/list_todo_card.dart';
import '../../invoicing/create_invoice_ui.dart';
import '../../task_items/task_items.g.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/text/text.g.dart';
import '../../widgets/widgets.g.dart';
import '../day_schedule.dart'; // Our DaySchedule stateful widget
import '../month_schedule.dart'; // Our MonthSchedule stateful widget
import '../week_schedule.dart';
import 'backup_reminder.dart';
import 'cache_reminder.dart';
import 'job_card.dart'; // Our WeekSchedule stateful widget

class JobAndCustomer {
  final Job job;
  final Customer customer;
  final Site? site;
  final String? bestPhoneNo;
  final String? bestEmailAddress;

  JobAndCustomer(
    this.job,
    this.customer,
    this.site,
    this.bestPhoneNo,
    this.bestEmailAddress,
  );

  static Future<JobAndCustomer> fetch(Job job) async {
    final customer = await DaoCustomer().getByJob(job.id);
    final site = await DaoSite().getByJob(job);

    final phoneNo = await DaoJob().getBestPhoneNumber(job);
    final emailAddress = await DaoJob().getBestEmail(job);
    return JobAndCustomer(job, customer!, site, phoneNo, emailAddress);
  }
}

class JobAndActivity {
  JobAndCustomer jobAndCustomer;
  JobActivity jobActivity;

  JobAndActivity(this.jobActivity, this.jobAndCustomer);

  static Future<JobAndActivity> fetch(JobActivity jobActivity) async {
    final job = await DaoJob().getById(jobActivity.jobId);
    final jobAndCustomer = await JobAndCustomer.fetch(job!);

    return JobAndActivity(jobActivity, jobAndCustomer);
  }
}

class Today {
  final List<JobAndActivity> activities;
  final List<ToDo> todos;
  final List<TaskItem> shopping;
  final List<TaskItem> packing;
  final List<Job> toBeQuoted;
  final List<InvoicingJob> toBeInvoiced;
  final BackupReminderStatus backupReminder;
  final CacheReminderStatus cacheReminder;

  Today._({
    required this.activities,
    required this.todos,
    required this.shopping,
    required this.packing,
    required this.toBeQuoted,
    required this.toBeInvoiced,
    required this.backupReminder,
    required this.cacheReminder,
  });

  static Future<Today> fetchToday() async {
    final today = LocalDate.today();
    final activities = await DaoJobActivity().getActivitiesForDate(today);
    final todos = await DaoToDo().getDueByDate(today);

    final daoTaskItems = DaoTaskItem();
    final daoJob = DaoJob();

    final activeJobs = <JobAndActivity>[];
    for (final activity in activities) {
      activeJobs.add(await JobAndActivity.fetch(activity));
    }

    final jobs = activeJobs
        .map((activeJob) => activeJob.jobAndCustomer.job)
        .toList();
    final shopping = jobs.isEmpty
        ? <TaskItem>[]
        : await daoTaskItems.getShoppingItems(jobs: jobs);
    final packing = jobs.isEmpty
        ? <TaskItem>[]
        : await daoTaskItems.getPackingItems(
            jobs: jobs,
            showPreApprovedTask: false,
            showPreScheduledJobs: false,
          );

    final toBeQuoted = await daoJob.getQuotableJobs(null);
    final readyJobs = await daoJob.readyToBeInvoiced(null);
    final unsentInvoices = await DaoInvoice().getUnsent();
    final byId = <int, InvoicingJob>{};
    for (final job in readyJobs) {
      byId[job.id] = InvoicingJob(job: job, hasUnsentInvoice: false);
    }
    for (final invoice in unsentInvoices) {
      final job = await daoJob.getById(invoice.jobId);
      if (job != null) {
        byId[job.id] = InvoicingJob(job: job, hasUnsentInvoice: true);
      }
    }
    final toBeInvoiced = byId.values.toList()
      ..sort((a, b) => b.job.modifiedDate.compareTo(a.job.modifiedDate));
    final backupReminder = await BackupReminder.getStatus();
    final cacheReminder = await CacheReminder.getStatus();

    return Today._(
      activities: activeJobs,
      todos: todos,
      shopping: shopping,
      packing: packing,
      toBeQuoted: toBeQuoted,
      toBeInvoiced: toBeInvoiced,
      backupReminder: backupReminder,
      cacheReminder: cacheReminder,
    );
  }
}

class InvoicingJob {
  final Job job;
  final bool hasUnsentInvoice;

  const InvoicingJob({required this.job, required this.hasUnsentInvoice});
}

/// The main schedule page. This is the "shell" that holds a [PageView]
/// of either
/// [DaySchedule], [WeekSchedule], or [MonthSchedule].
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => TodayPageState();
}

///
/// [TodayPageState]
///
class TodayPageState extends DeferredState<TodayPage> {
  late Today today;

  var todoRefresh = 0;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Today');
    today = await Today.fetchToday();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> refresh() async {
    today = await Today.fetchToday();
    todoRefresh++;
    setState(() {});
  }

  // BUILD
  @override
  Widget build(BuildContext context) => Scaffold(
    // appBar: AppBar(),
    body: DeferredBuilder(
      this,
      builder: (context) => HMBPadding(
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            child: HMBColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [..._buildCards()],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _buildCards() => [
    backupReminder(today),
    cacheReminder(today),
    jobList(today),
    todoList(today, refresh),
    shoppingList(today),
    packingList(today),
    quotingList(today),
    invoicingList(today),
  ];

  Widget backupReminder(Today today) => HMBOneOf(
    condition: !today.backupReminder.needsReminder,
    onTrue: const HMBEmpty(),
    onFalse: GestureDetector(
      onTap: () => context.go('/home/backup'),
      child: Surface(
        rounded: true,
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber),
            const HMBSpacer(width: true),
            Expanded(
              child: Text(
                _backupReminderMessage(today.backupReminder),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _backupReminderMessage(BackupReminderStatus status) {
    final parts = <String>[];
    if (status.dbBackupOverdue) {
      parts.add('Database backup is overdue');
    }
    if (status.photoSyncPending) {
      parts.add('Photo sync is pending');
    }
    return '${parts.join(' and ')}. Open Backup to resolve.';
  }

  Widget cacheReminder(Today today) => HMBOneOf(
    condition: !today.cacheReminder.needsReminder,
    onTrue: const HMBEmpty(),
    onFalse: GestureDetector(
      onTap: () => context.go('/home/settings/storage'),
      child: Surface(
        rounded: true,
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber),
            const HMBSpacer(width: true),
            Expanded(
              child: Text(
                _cacheReminderMessage(today.cacheReminder),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _cacheReminderMessage(CacheReminderStatus status) {
    final parts = <String>[];
    if (status.cacheLimitExceeded) {
      parts.add('Photo cache has exceeded its limit');
    }
    if (status.photoSyncPending) {
      parts.add('photo sync is pending');
    }
    return '${parts.join(' and ')}. Open Storage to resolve.';
  }

  Widget jobList(Today today) => Listing<JobAndActivity>(
    title: 'Jobs',
    list: today.activities,
    emptyMessage: 'No jobs scheduled for today.',
    cardBuilder: JobCard.new,
  );

  Widget todoList(Today today, VoidCallback onChange) => Listing<ToDo>(
    key: ValueKey(todoRefresh),
    title: 'To Do',
    list: today.todos,
    onChange: onChange,
    emptyMessage: 'No To Dos.',
    cardBuilder: (todo) => Column(
      children: [
        Row(
          children: [
            Checkbox(
              value: todo.status == ToDoStatus.done,
              onChanged: todo.status == ToDoStatus.closed
                  ? null
                  : (_) async {
                      await DaoToDo().toggleDone(todo);
                      await refresh();
                      HMBToast.info('Marked ${todo.title} as done');
                    },
            ),
            Expanded(child: HMBTextHeadline2(todo.title)),
          ],
        ),
        if (todo.parentType == ToDoParentType.job)
          FutureBuilderEx<Customer?>(
            future: DaoCustomer().getByJob(todo.parentId),
            builder: (context, customer) => HMBOneOf(
              condition: customer == null,
              onTrue: const HMBEmpty(),
              onFalse: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: HMBTextLine('Customer: ${customer!.name}'),
              ),
            ),
          ),
        ToDoCard(todo, (todo) => onChange()),
      ],
    ),
  );

  Widget shoppingList(Today today) => Listing<TaskItem>(
    title: 'Shopping',
    list: today.shopping,
    emptyMessage: 'No shopping for today.',
    cardBuilder: ShoppingCard.new,
    onTap: _openShoppingItem,
  );

  Widget packingList(Today today) => Listing<TaskItem>(
    title: 'Packing',
    list: today.packing,
    emptyMessage: 'No packing for today.',
    cardBuilder: PackingCard.new,
  );

  Widget quotingList(Today today) => Listing<Job>(
    title: 'Quoting',
    list: today.toBeQuoted,
    emptyMessage: 'No quotes for today.',
    cardBuilder: QuotingCard.new,
  );

  Widget invoicingList(Today today) => Listing<InvoicingJob>(
    title: 'Invoicing',
    list: today.toBeInvoiced,
    emptyMessage: 'No jobs need to be invoiced.',
    cardBuilder: InvoiceCard.new,
  );

  Future<void> _openShoppingItem(TaskItem taskItem) async {
    final task = await DaoTask().getById(taskItem.taskId);
    if (task == null || !mounted) {
      return;
    }

    final billingType = await DaoTask().getBillingTypeByTaskItem(taskItem);
    final wasReturned = await DaoTaskItem().wasReturned(taskItem.id);
    final itemContext = TaskItemContext(
      task: task,
      taskItem: taskItem,
      billingType: billingType,
      wasReturned: wasReturned,
    );

    if (!mounted) {
      return;
    }

    await markAsCompleted(itemContext, context);
    await refresh();
  }
}

// to do
class ToDoCard extends StatelessWidget {
  final ToDo todo;
  final void Function(ToDo) onChange;

  const ToDoCard(this.todo, this.onChange, {super.key});

  @override
  Widget build(BuildContext context) => Surface(
    rounded: true,
    child: ListTodoCard(todo: todo, onChange: onChange),
  );
}

// shopping
class ShoppingCard extends StatelessWidget {
  final TaskItem taskItem;

  const ShoppingCard(this.taskItem, {super.key});

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
    future: JobAndTask.fetch(taskItem),
    builder: (context, jobAndCustomer) => Surface(
      rounded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HMBText(jobAndCustomer!.customer.name),
          HMBText(jobAndCustomer.job.summary),
          HMBText(jobAndCustomer.task.name),
          HMBText(taskItem.description),
        ],
      ),
    ),
  );
}

class PackingCard extends StatelessWidget {
  final TaskItem taskItem;

  const PackingCard(this.taskItem, {super.key});

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
    future: JobAndTask.fetch(taskItem),
    builder: (context, jobAndCustomer) => Surface(
      rounded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HMBText(jobAndCustomer!.customer.name),
          HMBText(jobAndCustomer.job.summary),
          HMBText(jobAndCustomer.task.name),
          HMBText(taskItem.description),
        ],
      ),
    ),
  );
}

class QuotingCard extends StatelessWidget {
  final Job job;

  const QuotingCard(this.job, {super.key});

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
    future: JobAndCustomer.fetch(job),
    builder: (context, jobAndCustomer) => Surface(
      rounded: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HMBText(jobAndCustomer!.job.summary),
              HMBText(jobAndCustomer.customer.name),
            ],
          ),
        ],
      ),
    ),
  );
}

class InvoiceCard extends StatelessWidget {
  final InvoicingJob invoicingJob;

  const InvoiceCard(this.invoicingJob, {super.key});

  @override
  @override
  Widget build(BuildContext context) => FutureBuilderEx(
    future: JobAndCustomer.fetch(invoicingJob.job),
    builder: (context, jobAndCustomer) => Surface(
      rounded: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HMBText(jobAndCustomer!.job.summary),
              HMBText(jobAndCustomer.customer.name),
              if (invoicingJob.hasUnsentInvoice)
                const Text(
                  'Unsent invoice',
                  style: TextStyle(color: Colors.orange),
                ),
            ],
          ),

          HMBButtonAdd(
            hint: invoicingJob.hasUnsentInvoice
                ? 'Open invoice list and send outstanding invoice'
                : 'Add Invoice',
            small: true,
            enabled: true,
            onAdd: () => createInvoiceFor(invoicingJob.job, context),
          ),
        ],
      ),
    ),
  );
}

class Listing<T> extends StatelessWidget {
  final String title;
  final List<T> list;
  final Widget Function(T) cardBuilder;
  final Future<void> Function(T)? onTap;
  final void Function()? onChange;
  final String emptyMessage;

  const Listing({
    required this.title,
    required this.list,
    required this.cardBuilder,
    required this.emptyMessage,
    this.onTap,
    this.onChange,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: double.infinity,
        child: HMBTextHeadline2(
          title,
          backgroundColor: HMBColors.listCardBackgroundSelected,
        ),
      ),
      HMBOneOf(
        condition: list.isEmpty,
        onTrue: HMBText(emptyMessage),
        onFalse: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: list
              .map(
                (entity) => Surface(
                  rounded: true,
                  padding: EdgeInsets.zero,
                  child: onTap == null
                      ? cardBuilder(entity)
                      : GestureDetector(
                          onTap: () => unawaited(onTap!(entity)),
                          child: cardBuilder(entity),
                        ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

class JobAndTask {
  final Customer customer;
  final Job job;
  final Task task;
  final TaskItem taskItem;

  JobAndTask._(this.customer, this.job, this.task, this.taskItem);

  static Future<JobAndTask> fetch(TaskItem taskItem) async {
    final task = await DaoTask().getTaskForItem(taskItem);

    final job = await DaoJob().getJobForTask(task.id);
    final customer = await DaoCustomer().getByJob(job!.id);

    return JobAndTask._(customer!, job, task, taskItem);
  }
}
