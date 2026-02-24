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

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../dialog/source_context.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';
import '../base_nested/list_nested_screen.dart';
import 'build_send_task_approval_button.dart';
import 'edit_task_approval_screen.dart';

class TaskApprovalListScreen extends StatefulWidget {
  final Parent<Job> parent;

  const TaskApprovalListScreen({required this.parent, super.key});

  @override
  State<TaskApprovalListScreen> createState() => _TaskApprovalListScreenState();
}

class _TaskApprovalListScreenState extends State<TaskApprovalListScreen> {
  @override
  Widget build(BuildContext context) =>
      NestedEntityListScreen<TaskApproval, Job>(
        title: (approval) => Text('Task Approval #${approval.id}'),
        parent: widget.parent,
        parentTitle: 'Job',
        entityNamePlural: 'Task Approvals',
        entityNameSingular: 'Task Approval',
        dao: DaoTaskApproval(),
        fetchList: () => DaoTaskApproval().getByJob(widget.parent.parent!.id),
        details: (approval, details) => FutureBuilderEx(
          future: _TaskApprovalDetails.get(approval),
          builder: (context, info) {
            final details = info!;
            final visibleTasks = details.tasks.take(2).toList();
            final remaining = details.tasks.length - visibleTasks.length;
            return HMBColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer : ${details.customer.name}'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Contact : ${details.contact.fullname}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    HMBPhoneIcon(
                      details.contact.fullname,
                      sourceContext: SourceContext(
                        customer: details.customer,
                        contact: details.contact,
                      ),
                    ),
                    HMBMailToIcon(details.contact.emailAddress),
                  ],
                ),
                BuildSendTaskApprovalButton(
                  context: context,
                  mounted: context.mounted,
                  approval: approval,
                ),
                const SizedBox(height: 8),
                const Text('Tasks:'),
                ...visibleTasks.map(
                  (view) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${view.task.name} (${view.link.status.name})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _cycleDecision(view.link),
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
                if (remaining > 0) Text('+ $remaining more task(s)'),
              ],
            );
          },
        ),
        onEdit: (approval) => TaskApprovalEditScreen(
          job: widget.parent.parent!,
          approval: approval,
        ),
        onDelete: (approval) => DaoTaskApproval().delete(approval.id),
        cardHeight: 300,
      );

  Future<void> _cycleDecision(TaskApprovalTask link) async {
    final next = switch (link.status) {
      TaskApprovalDecision.pending => TaskApprovalDecision.approved,
      TaskApprovalDecision.approved => TaskApprovalDecision.rejected,
      TaskApprovalDecision.rejected => TaskApprovalDecision.pending,
    };
    await DaoTaskApprovalTask().updateDecision(
      approvalTask: link,
      decision: next,
    );
    if (mounted) {
      setState(() {});
    }
  }
}

class _TaskApprovalTaskView {
  final Task task;
  final TaskApprovalTask link;

  _TaskApprovalTaskView(this.task, this.link);
}

class _TaskApprovalDetails {
  final Customer customer;
  final Contact contact;
  final List<_TaskApprovalTaskView> tasks;

  _TaskApprovalDetails._(this.customer, this.contact, this.tasks);

  static Future<_TaskApprovalDetails> get(TaskApproval approval) async {
    final job = await DaoJob().getById(approval.jobId);
    if (job == null || job.customerId == null) {
      throw StateError(
        'Task approval ${approval.id} has no valid job/customer',
      );
    }
    final customer = await DaoCustomer().getById(job.customerId);
    final contact = await DaoContact().getById(approval.contactId);
    if (customer == null || contact == null) {
      throw StateError(
        'Task approval ${approval.id} has a missing customer/contact',
      );
    }

    final links = await DaoTaskApprovalTask().getByApproval(approval.id);
    final tasks = <_TaskApprovalTaskView>[];
    for (final link in links) {
      final task = await DaoTask().getById(link.taskId);
      if (task != null) {
        tasks.add(_TaskApprovalTaskView(task, link));
      }
    }

    return _TaskApprovalDetails._(customer, contact, tasks);
  }
}
