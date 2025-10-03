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

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:sqflite/sqlite_api.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/hmb_column.dart';
import '../../widgets/select/select.g.dart';
import '../base_nested/edit_nested_screen.dart';

class AssignmentEditScreen extends StatefulWidget {
  final WorkAssignment? assignment;
  final Job job;

  const AssignmentEditScreen({required this.job, super.key, this.assignment});

  @override
  _AssignmentEditScreenState createState() => _AssignmentEditScreenState();
}

class _AssignmentEditScreenState extends DeferredState<AssignmentEditScreen>
    implements NestedEntityState<WorkAssignment> {
  @override
  WorkAssignment? currentEntity;
  int? _selectedSupplier;
  int? _selectedContact;
  Set<int> _selectedTasks = {};

  @override
  Future<void> asyncInitState() async {
    currentEntity = widget.assignment;
    _selectedSupplier = currentEntity?.supplierId;
    _selectedContact = currentEntity?.contactId;

    if (currentEntity != null) {
      final tasks = await DaoWorkAssignmentTask().getByAssignment(
        currentEntity!.id,
      );
      _selectedTasks = tasks.map((j) => j.taskId).toSet();
    }
  }

  @override
  Future<WorkAssignment> forInsert() async => WorkAssignment.forInsert(
    jobId: widget.job.id,
    supplierId: _selectedSupplier!,
    contactId: _selectedContact!,
  );

  @override
  Future<WorkAssignment> forUpdate(WorkAssignment e) async => e.copyWith(
    jobId: e.jobId,
    supplierId: _selectedSupplier,
    contactId: _selectedContact,
  );
  @override
  Future<void> postSave(Transaction transaction, Operation operation) async {
    final dao = DaoWorkAssignmentTask();
    if (operation == Operation.update) {
      await dao.deleteByAssignment(currentEntity!.id, transaction: transaction);
    }
    for (final taskId in _selectedTasks) {
      await dao.insert(
        WorkAssignmentTask.forInsert(
          assignmentId: currentEntity!.id,
          taskId: taskId,
        ),
        transaction,
      );
    }
  }

  @override
  Widget build(BuildContext ctx) => DeferredBuilder(
    this,
    builder: (_) => NestedEntityEditScreen<WorkAssignment, Job>(
      entityName: 'Assignment',
      dao: DaoWorkAssignment(),
      onInsert: (workAssignment, transaction) =>
          DaoWorkAssignment().insert(workAssignment!, transaction),
      entityState: this,
      editor: (workAssignment) => _buildEditor(),
      crossValidator: () async {
        if (_selectedTasks.isEmpty) {
          HMBToast.error('You must select at least one Task');
          return false;
        }

        // for some reason the required flag on the drop list isn't triggering.
        if (_selectedContact == null) {
          HMBToast.error('You must select the Supplier Contact');
          return false;
        }

        return true;
      },
    ),
  );

  Widget _buildEditor() => SingleChildScrollView(
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Supplier selector
        FutureBuilderEx<List<Supplier>>(
          future: DaoSupplier().getAll(orderByClause: 'name COLLATE NOCASE'),
          builder: (c, suppliers) => HMBDroplist<Supplier>(
            selectedItem: () => DaoSupplier().getById(_selectedSupplier),
            title: 'Supplier',
            format: (supplier) => supplier.name,
            items: (filter) async => suppliers!
                .where(
                  (supplier) => supplier.name.toLowerCase().contains(
                    filter!.toLowerCase(),
                  ),
                )
                .toList(),
            onChanged: (supplier) {
              _selectedSupplier = supplier?.id;
              _selectedContact = null;
              // force the contact drop list to show, now
              // that we have a supplier.
              setState(() {});
            },
          ),
        ),


        // Supplier-Contact selector
        if (_selectedSupplier != null) ...[
          FutureBuilderEx<List<Contact>>(
            future: DaoContactSupplier().getBySupplier(_selectedSupplier!),
            builder: (context, contacts) => HMBDroplist<Contact>(
              selectedItem: () => DaoContact().getById(_selectedContact),
              title: 'Supplier Contact',
              format: (contacts) => contacts.fullname,
              items: (filter) async => contacts!,
              onChanged: (contact) => _selectedContact = contact?.id,
            ),
          ),

        ],

        // Tasks multi-select
        FutureBuilder<List<Task>>(
          future: DaoTask().getTasksByJob(widget.job.id),
          builder: (c, snap) {
            final tasks = snap.data ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tasks to assign',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...tasks
                    .
                    /// exclude tasks that are cancelled or on hold.
                    where(
                      (task) =>
                          !(task.status == TaskStatus.cancelled ||
                              task.status == TaskStatus.onHold),
                    )
                    .map(
                      (t) => CheckboxListTile(
                        value: _selectedTasks.contains(t.id),
                        title: Text(
                          t.name,
                          style: const TextStyle(color: Colors.blue),
                        ),
                        subtitle: Text(t.assumption),
                        onChanged: (on) => setState(() {
                          if (on ?? false) {
                            _selectedTasks.add(t.id);
                          } else {
                            _selectedTasks.remove(t.id);
                          }
                        }),
                      ),
                    ),
              ],
            );
          },
        ),
      ],
    ),
  );

  @override
  void refresh() {
    setState(() {});
  }
}
