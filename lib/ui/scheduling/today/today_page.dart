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

// -- Example imports. Adapt for your project:
import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/local_date.dart';
import '../../../util/flutter/app_title.dart';
import '../../invoicing/create_invoice_ui.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/text/text.g.dart';
import '../../widgets/widgets.g.dart';
import '../day_schedule.dart'; // Our DaySchedule stateful widget
import '../month_schedule.dart'; // Our MonthSchedule stateful widget
import '../week_schedule.dart';
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
  final List<Job> toBeInvoiced;

  Today._({
    required this.activities,
    required this.todos,
    required this.shopping,
    required this.packing,
    required this.toBeQuoted,
    required this.toBeInvoiced,
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
    final toBeInvoiced = await daoJob.readyToBeInvoiced(null);

    return Today._(
      activities: activeJobs,
      todos: todos,
      shopping: shopping,
      packing: packing,
      toBeQuoted: toBeQuoted,
      toBeInvoiced: toBeInvoiced,
    );
  }
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
  late final Today today;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Today');
    today = await Today.fetchToday();
  }

  @override
  void dispose() {
    super.dispose();
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [..._buildCards()],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _buildCards() => [
    ...jobList(today),
    ...todoList(today),
    ...shoppingList(today),
    ...packingList(today),
    ...quotingList(today),
    ...invoicingList(today),
  ];
}

List<Widget> jobList(Today today) => [
  const HMBTextHeadline2('Jobs'),
  HMBOneOf(
    condition: today.activities.isEmpty,
    onTrue: const HMBText('No jobs scheduled for today.'),
    onFalse: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: today.activities.map(JobCard.new).toList(),
    ),
  ),
];

List<Widget> todoList(Today today) => [
  const HMBTextHeadline2('To Do'),
  HMBOneOf(
    condition: today.todos.isEmpty,
    onTrue: const Surface(rounded: true, child: HMBText('No To Dos.')),
    onFalse: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: today.todos.map(ToDoCard.new).toList(),
    ),
  ),
];

List<Widget> shoppingList(Today today) => [
  const HMBTextHeadline2('Shopping'),
  Surface(
    rounded: true,
    child: HMBOneOf(
      condition: today.shopping.isEmpty,
      onTrue: const HMBText('No shopping for today.'),
      onFalse: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: today.shopping.map(ShoppingCard.new).toList(),
      ),
    ),
  ),
];

List<Widget> packingList(Today today) => [
  const HMBTextHeadline2('Packing'),
  HMBOneOf(
    condition: today.packing.isEmpty,
    onTrue: const Surface(
      rounded: true,
      child: HMBText('No packing for today.'),
    ),
    onFalse: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: today.packing.map(PackingCard.new).toList(),
    ),
  ),
];

List<Widget> quotingList(Today today) => [
  const HMBTextHeadline2('Quoting'),
  HMBOneOf(
    condition: today.toBeQuoted.isEmpty,
    onTrue: const Surface(
      rounded: true,
      child: HMBText('No quotes for today.'),
    ),
    onFalse: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: today.toBeQuoted.map(QuotingCard.new).toList(),
    ),
  ),
];
List<Widget> invoicingList(Today today) => [
  const HMBTextHeadline2('Invoicing'),
  HMBOneOf(
    condition: today.toBeInvoiced.isEmpty,
    onTrue: const Surface(
      rounded: true,
      child: HMBText('No jobs need to be invoiced.'),
    ),
    onFalse: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: today.toBeInvoiced.map(InvoiceCard.new).toList(),
    ),
  ),
];

class ToDoCard extends StatelessWidget {
  final ToDo todo;

  const ToDoCard(this.todo, {super.key});

  @override
  Widget build(BuildContext context) =>
      Surface(rounded: true, child: HMBText(todo.title));
}

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
          HMBText(jobAndCustomer!.job.summary),
          HMBText(jobAndCustomer.job.summary),
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
          HMBText(jobAndCustomer!.job.summary),
          HMBText(jobAndCustomer.job.summary),
          HMBText(taskItem.description),
        ],
      ),
    ),
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
  final Job job;

  const InvoiceCard(this.job, {super.key});

  @override
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

          HMBButtonAdd(
            hint: 'Add Invoice',
            small: true,
            enabled: true,
            onAdd: () => createInvoiceFor(job, context),
          ),
        ],
      ),
    ),
  );
}
