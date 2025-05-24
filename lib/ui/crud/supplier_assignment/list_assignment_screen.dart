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
  const AssignmentListScreen({required this.job, super.key});

  final Job job;

  @override
  Widget build(BuildContext context) =>
      NestedEntityListScreen<SupplierAssignment, Job>(
        title: (assignment) => Text('Assignment #${assignment.id}'),
        parent: Parent(job),
        parentTitle: 'Job',
        entityNamePlural: 'Supplier Assignments',
        entityNameSingular: 'Supplier Assignment',
        dao: DaoSupplierAssignment(),
        fetchList: () => DaoSupplierAssignment().getByJob(job.id),
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
            AssignmentEditScreen(job: job, assignment: assignment),
        onDelete: (assignment) =>
            DaoSupplierAssignment().delete(assignment!.id),
        onInsert: (assignment, tx) =>
            DaoSupplierAssignment().insert(assignment!, tx),
        cardHeight: 180,
      );
}

class SupplierAndTasks {
  SupplierAndTasks._(this.supplier, this.contact, this.tasks);

  static Future<SupplierAndTasks> get(SupplierAssignment assignment) async {
    final supplier = await DaoSupplier().getById(assignment.supplierId);
    final contact = await DaoContact().getById(assignment.contactId);

    final assignedTasks = await DaoSupplierAssignmentTask().getByAssignment(
      assignment.id,
    );

    final tasks = <Task>[];
    for (final assignedTask in assignedTasks) {
      tasks.add((await DaoTask().getById(assignedTask.taskId))!);
    }

    return SupplierAndTasks._(supplier!, contact!, tasks);
  }

  final Supplier supplier;
  final Contact contact;

  final List<Task> tasks;
}
