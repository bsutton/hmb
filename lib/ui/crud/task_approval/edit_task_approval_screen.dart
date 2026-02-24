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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:sqflite_common/sqflite.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/hmb_column.dart';
import '../../widgets/select/select.g.dart';
import '../base_nested/edit_nested_screen.dart';

class TaskApprovalEditScreen extends StatefulWidget {
  final TaskApproval? approval;
  final Job job;

  const TaskApprovalEditScreen({required this.job, super.key, this.approval});

  @override
  _TaskApprovalEditScreenState createState() => _TaskApprovalEditScreenState();
}

class _TaskApprovalEditScreenState extends DeferredState<TaskApprovalEditScreen>
    implements NestedEntityState<TaskApproval> {
  @override
  TaskApproval? currentEntity;
  int? _selectedContact;
  Set<int> _selectedTasks = {};
  Set<int> _originalTaskIds = {};
  final Map<int, TaskApprovalDecision> _existingStatusByTaskId = {};

  @override
  Future<void> asyncInitState() async {
    currentEntity = widget.approval;
    _selectedContact = currentEntity?.contactId;

    if (currentEntity != null) {
      final links = await DaoTaskApprovalTask().getByApproval(
        currentEntity!.id,
      );
      _selectedTasks = links.map((j) => j.taskId).toSet();
      _originalTaskIds = {..._selectedTasks};
      for (final link in links) {
        _existingStatusByTaskId[link.taskId] = link.status;
      }
    }
  }

  @override
  Future<TaskApproval> forInsert() async => TaskApproval.forInsert(
    jobId: widget.job.id,
    contactId: _selectedContact!,
  );

  @override
  Future<TaskApproval> forUpdate(TaskApproval e) async {
    final changed =
        _selectedContact != e.contactId ||
        !setEquals(_selectedTasks, _originalTaskIds);
    final status = e.status == TaskApprovalStatus.sent && changed
        ? TaskApprovalStatus.modified
        : e.status;
    return e.copyWith(contactId: _selectedContact, status: status);
  }

  @override
  Future<void> postSave(Transaction transaction, Operation operation) async {
    final dao = DaoTaskApprovalTask();
    if (operation == Operation.update) {
      await dao.deleteByApproval(currentEntity!.id, transaction: transaction);
    }
    for (final taskId in _selectedTasks) {
      await dao.insert(
        TaskApprovalTask.forInsert(
          approvalId: currentEntity!.id,
          taskId: taskId,
          status:
              _existingStatusByTaskId[taskId] ?? TaskApprovalDecision.pending,
        ),
        transaction,
      );
    }
  }

  @override
  Widget build(BuildContext ctx) => DeferredBuilder(
    this,
    builder: (_) => NestedEntityEditScreen<TaskApproval, Job>(
      entityName: 'Task Approval',
      dao: DaoTaskApproval(),
      onInsert: (approval, transaction) =>
          DaoTaskApproval().insert(approval!, transaction),
      entityState: this,
      editor: (approval) => _buildEditor(),
      crossValidator: () async {
        if (_selectedTasks.isEmpty) {
          HMBToast.error('You must select at least one Task');
          return false;
        }
        if (_selectedContact == null) {
          HMBToast.error('You must select the Customer Contact');
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
        FutureBuilderEx<List<Contact>>(
          future: DaoContact().getByCustomer(widget.job.customerId),
          builder: (context, contacts) => HMBDroplist<Contact>(
            selectedItem: () => DaoContact().getById(_selectedContact),
            title: 'Customer Contact',
            format: (contact) => contact.fullname,
            items: (filter) async => contacts!,
            onChanged: (contact) => _selectedContact = contact?.id,
          ),
        ),
        FutureBuilder<List<Task>>(
          future: DaoTask().getTasksByJob(widget.job.id),
          builder: (c, snap) {
            final tasks = (snap.data ?? [])
                .where(
                  (task) =>
                      _selectedTasks.contains(task.id) ||
                      !(task.status == TaskStatus.cancelled ||
                          task.status == TaskStatus.onHold),
                )
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tasks for customer approval',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...tasks.map(
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
