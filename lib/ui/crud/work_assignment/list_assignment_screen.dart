/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/ui/assignment/list_assignment_screen.dart

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../dialog/source_context.dart';
import '../../widgets/widgets.g.dart';
import '../base_nested/list_nested_screen.dart';
import 'build_send_assignment_button.dart';
import 'edit_assignment_screen.dart';

class AssignmentListScreen extends StatelessWidget {
  const AssignmentListScreen({required this.parent, super.key});

  final Parent<Job> parent;

  @override
  Widget build(BuildContext context) =>
      NestedEntityListScreen<WorkAssignment, Job>(
        title: (assignment) => Text('Assignment #${assignment.id}'),
        parent: parent,
        parentTitle: 'Job',
        entityNamePlural: 'Supplier Assignments',
        entityNameSingular: 'Supplier Assignment',
        dao: DaoWorkAssigment(),
        fetchList: () => DaoWorkAssigment().getByJob(parent.parent!.id),
        details: (assignment, details) => FutureBuilderEx(
          future: SupplierAndTasks.get(assignment),
          builder: (context, supplierAndTasks) => Column(
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
              const SizedBox(height: 8),
              BuildSendAssignmentButton(
                context: context,
                mounted: context.mounted,
                assignment: assignment,
              ),
            ],
          ),
        ),
        onEdit: (assignment) =>
            AssignmentEditScreen(job: parent.parent!, assignment: assignment),
        onDelete: (assignment) => DaoWorkAssigment().delete(assignment.id),
        cardHeight: 200,
      );
}

class SupplierAndTasks {
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

  final Supplier supplier;
  final Contact contact;

  final List<Task> tasks;
}
