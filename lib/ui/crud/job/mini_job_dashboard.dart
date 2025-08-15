/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../dao/dao_todo.dart';
import '../../../entity/job.dart';
import '../../invoicing/list_invoice_screen.dart';
import '../../nav/dashboards/dashlet_card.dart';
import '../../quoting/list_quote_screen.dart';
import '../../widgets/layout/hmb_full_page_child_screen.dart';
import '../base_nested/list_nested_screen.dart';
import '../task/list_task_screen.dart';
import '../todo/list_todo_screen.dart';
import '../work_assignment/list_assignment_screen.dart';
import 'esitmator/edit_job_estimate_screen.dart';
import 'tracking/list_time_entry_screen.dart';

/// A compact dashboard for a single Job,
/// displaying fixed-size DashletCards in one or more rows.
class MiniJobDashboard extends StatelessWidget {
  const MiniJobDashboard({required this.job, super.key});
  final Job job;

  @override
  Widget build(BuildContext context) {
    const dashletSize = 100.0;
    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _dashlet(
            child: DashletCard<String>.builder(
              label: 'Estimate',
              hint: "Build an Estimate of a Job's cost",
              icon: Icons.calculate,
              compact: true,
              value: () async => const DashletValue(''),
              builder: (_, _) => JobEstimateBuilderScreen(job: job),
            ),
            size: dashletSize,
          ),
          _dashlet(
            child: DashletCard<int>.builder(
              label: 'Quotes',
              hint: 'Quote a job based on an Estimate',
              icon: Icons.format_quote,
              compact: true,
              value: () async {
                final all = await DaoQuote().getByFilter(null);
                final list = all.where((q) => q.jobId == job.id).toList();
                return DashletValue<int>(list.length);
              },
              builder: (_, _) => HMBFullPageChildScreen(
                title: 'Quotes',
                child: QuoteListScreen(job: job),
              ),

              // route: '/home/jobs/quotes/${job.id}',
            ),
            size: dashletSize,
          ),
          _dashlet(
            child: DashletCard<int>.builder(
              label: 'Tasks',
              hint: 'Task to be completed for this Job',
              icon: Icons.task,
              compact: true,
              value: () async {
                final all = await DaoTask().getTasksByJob(job.id);
                return DashletValue<int>(all.length);
              },
              builder: (_, _) => HMBFullPageChildScreen(
                title: 'Tasks',
                child: TaskListScreen(parent: Parent(job), extended: true),
              ),

              // route: '/home/jobs/quotes/${job.id}',
            ),
            size: dashletSize,
          ),
          _dashlet(
            child: DashletCard<int>.builder(
              label: 'Assign',
              hint: 'Assign tasks to sub-contractors (Suppliers)',
              icon: Icons.task,
              compact: true,
              value: () async {
                final all = await DaoWorkAssigment().getByJob(job.id);
                return DashletValue<int>(all.length);
              },
              builder: (_, _) => HMBFullPageChildScreen(
                title: 'Assignments',
                child: AssignmentListScreen(parent: Parent(job)),
              ),

              // route: '/home/jobs/quotes/${job.id}',
            ),
            size: dashletSize,
          ),
          _dashlet(
            child: DashletCard<int>.builder(
              label: 'Todo',
              hint: 'Add action items to the job',
              icon: Icons.task,
              compact: true,
              value: () async {
                final all = await DaoToDo().getByJob(job.id);
                return DashletValue<int>(all.length);
              },
              builder: (_, _) => const HMBFullPageChildScreen(
                title: 'Todo',
                child: ToDoListScreen(),
              ),

              // route: '/home/jobs/quotes/${job.id}',
            ),
            size: dashletSize,
          ),
          _dashlet(
            child: DashletCard<int>.builder(
              label: 'Track',
              hint: 'Track and View time recorded against Job Tasks',
              icon: Icons.access_time,
              compact: true,
              value: () async {
                final list = await DaoTimeEntry().getByJob(job.id);
                return DashletValue<int>(list.length);
              },

              builder: (_, _) => HMBFullPageChildScreen(
                title: 'Time Entries',
                child: TimeEntryListScreen(job: job),
              ),
              // route: '/home/jobs/track/${job.id}',
            ),
            size: dashletSize,
          ),
          _dashlet(
            child: DashletCard<int>.builder(
              label: 'Invoices',
              hint: 'Invoice a Job',
              icon: Icons.attach_money,
              compact: true,
              value: () async {
                final all = await DaoInvoice().getByFilter(null);
                final list = all.where((i) => i.jobId == job.id).toList();
                return DashletValue<int>(list.length);
              },
              builder: (_, _) => HMBFullPageChildScreen(
                title: 'Invoices',
                child: InvoiceListScreen(job: job),
              ),

              // route: '/home/jobs/invoices/${job.id}',
            ),
            size: dashletSize,
          ),
        ],
      ),
    );
  }

  /// Wraps a dashlet in a fixed-size container
  Widget _dashlet({required Widget child, required double size}) =>
      SizedBox(width: size, height: size, child: child);
}
