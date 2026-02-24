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

// lib/src/ui/assignment/list_assignment_screen.dart

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../dialog/source_context.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';
import '../base_nested/list_nested_screen.dart';
import 'build_send_assignment_button.dart';
import 'edit_assignment_screen.dart';

class AssignmentListScreen extends StatefulWidget {
  final Parent<Job> parent;

  const AssignmentListScreen({required this.parent, super.key});

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  @override
  Widget build(BuildContext context) =>
      NestedEntityListScreen<WorkAssignment, Job>(
        title: (assignment) => Text('Task Approval #${assignment.id}'),
        parent: widget.parent,
        parentTitle: 'Job',
        entityNamePlural: 'Task Approvals',
        entityNameSingular: 'Task Approval',
        dao: DaoWorkAssignment(),
        fetchList: () => DaoWorkAssignment().getByJob(widget.parent.parent!.id),
        details: (assignment, details) => FutureBuilderEx(
          future: SupplierAndTasks.get(assignment),
          builder: (context, supplierAndTasks) => HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supplier : ${supplierAndTasks!.supplier.name}'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Contact : ${supplierAndTasks.contact.fullname}'),
                  HMBPhoneIcon(
                    supplierAndTasks.contact.fullname,
                    sourceContext: SourceContext(
                      supplier: supplierAndTasks.supplier,
                      contact: supplierAndTasks.contact,
                    ),
                  ),
                  HMBMailToIcon(supplierAndTasks.contact.emailAddress),
                ],
              ),
              BuildSendAssignmentButton(
                context: context,
                mounted: context.mounted,
                assignment: assignment,
              ),
              const SizedBox(height: 8),
              const Text('Tasks for approval:'),
              ...supplierAndTasks.tasks.map(
                (task) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${task.name} (${task.status.name})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _toggleTaskRejected(task),
                      child: Text(
                        task.status == TaskStatus.cancelled
                            ? 'Unreject'
                            : 'Reject',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        onEdit: (assignment) => AssignmentEditScreen(
          job: widget.parent.parent!,
          assignment: assignment,
        ),
        onDelete: (assignment) => DaoWorkAssignment().delete(assignment.id),
        cardHeight: 300,
      );

  Future<void> _toggleTaskRejected(Task task) async {
    if (task.status == TaskStatus.cancelled) {
      await DaoTask().markUnrejected(task.id);
    } else {
      await DaoTask().markRejected(task.id);
    }

    if (mounted) {
      setState(() {});
    }
  }
}

class SupplierAndTasks {
  final Supplier supplier;
  final Contact contact;
  final List<Task> tasks;

  SupplierAndTasks._(this.supplier, this.contact, this.tasks);

  static Future<SupplierAndTasks> get(WorkAssignment assignment) async {
    final supplier = await DaoSupplier().getById(assignment.supplierId);
    final contact = await DaoContact().getById(assignment.contactId);

    final assignedTasks = await DaoWorkAssignmentTask().getByAssignment(
      assignment.id,
    );

    final tasks = <Task>[];
    for (final assignedTask in assignedTasks) {
      final task = await DaoTask().getById(assignedTask.taskId);
      // we shouldn't get a null, but a version was released that allows
      // deleting a task without deleting a the assignment so
      // this is a work around and probably generally prudent.
      if (task != null) {
        tasks.add(task);
      }
    }

    return SupplierAndTasks._(supplier!, contact!, tasks);
  }
}
