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
import '../../../util/flutter/flutter_util.g.dart';
import '../../crud/todo/list_todo_card.dart';
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
    jobList(today),
    todoList(today, refresh),
    shoppingList(today),
    packingList(today),
    quotingList(today),
    invoicingList(today),
  ];

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
              onChanged: (_) async {
                await DaoToDo().toggleDone(todo);
                await refresh();
                HMBToast.info('Marked ${todo.title} as done');
              },
            ),
            Expanded(child: HMBTextHeadline2(todo.title)),
          ],
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

  Widget invoicingList(Today today) => Listing<Job>(
    title: 'Invoicing',
    list: today.toBeInvoiced,
    emptyMessage: 'No jobs need to be invoiced.',
    cardBuilder: InvoiceCard.new,
  );
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

class Listing<T> extends StatelessWidget {
  final String title;
  final List<T> list;
  final Widget Function(T) cardBuilder;
  final void Function()? onChange;
  final String emptyMessage;

  const Listing({
    required this.title,
    required this.list,
    required this.cardBuilder,
    required this.emptyMessage,
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
                  child: cardBuilder(entity),
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
