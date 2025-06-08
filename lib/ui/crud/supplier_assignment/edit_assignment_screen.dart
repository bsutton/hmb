import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:sqflite/sqlite_api.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/util.g.dart';
import '../../widgets/select/select.g.dart';
import '../base_nested/edit_nested_screen.dart';

class AssignmentEditScreen extends StatefulWidget {
  const AssignmentEditScreen({required this.job, super.key, this.assignment});

  final SupplierAssignment? assignment;
  final Job job;

  @override
  _AssignmentEditScreenState createState() => _AssignmentEditScreenState();
}

class _AssignmentEditScreenState extends DeferredState<AssignmentEditScreen>
    implements NestedEntityState<SupplierAssignment> {
  @override
  SupplierAssignment? currentEntity;
  int? _selectedSupplier;
  int? _selectedContact;
  Set<int> _selectedTasks = {};

  @override
  Future<void> asyncInitState() async {
    currentEntity = widget.assignment;
    _selectedSupplier = currentEntity?.supplierId;
    _selectedContact = currentEntity?.contactId;

    if (currentEntity != null) {
      final tasks = await DaoSupplierAssignmentTask().getByAssignment(
        currentEntity!.id,
      );
      _selectedTasks = tasks.map((j) => j.taskId).toSet();
    }
  }

  @override
  Future<SupplierAssignment> forInsert() async => SupplierAssignment.forInsert(
    jobId: widget.job.id,
    supplierId: _selectedSupplier!,
    contactId: _selectedContact!,
  );

  @override
  Future<SupplierAssignment> forUpdate(SupplierAssignment e) async =>
      SupplierAssignment.forUpdate(
        entity: e,
        jobId: e.jobId,
        supplierId: _selectedSupplier!,
        contactId: _selectedContact!,
      );
  @override
  Future<void> postSave(Transaction transaction, Operation operation) async {
    final dao = DaoSupplierAssignmentTask();
    if (operation == Operation.update) {
      await dao.deleteByAssignment(currentEntity!.id, transaction: transaction);
    }
    for (final taskId in _selectedTasks) {
      await dao.insert(
        SupplierAssignmentTask.forInsert(
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
    builder:
        (_) => NestedEntityEditScreen<SupplierAssignment, Job>(
          entityName: 'Assignment',
          dao: DaoSupplierAssignment(),
          onInsert:
              (supplierAssignment, transaction) async => DaoSupplierAssignment()
                  .insert(supplierAssignment!, transaction),
          entityState: this,
          editor: (supplierAssignment) => _buildEditor(),
          
          // crossValidator:
          //     () async => _selectedSupplier != null && _selectedContact != null,
        ),
  );

  Widget _buildEditor() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Supplier selector
        FutureBuilderEx<List<Supplier>>(
          future: DaoSupplier().getAll(orderByClause: 'name COLLATE NOCASE'),
          builder:
              (c, suppliers) => HMBDroplist<Supplier>(
                selectedItem:
                    () async => DaoSupplier().getById(_selectedSupplier),
                title: 'Supplier',
                format: (supplier) => supplier.name,
                items: (filter) async => suppliers!,
                onChanged: (supplier) {
                  _selectedSupplier = supplier?.id;
                  // force the contact drop list to show, now
                  // that we have a supplier.
                  setState(() {});
                },
              ),
        ),

        const SizedBox(height: 16),

        // Supplier-Contact selector
        if (_selectedSupplier != null) ...[
          FutureBuilderEx<List<Contact>>(
            future: DaoContactSupplier().getBySupplier(_selectedSupplier!),
            builder:
                (context, contacts) => HMBDroplist<Contact>(
                  selectedItem:
                      () async => DaoContact().getById(_selectedContact),
                  title: 'Supplier Contact',
                  format: (contacts) => contacts.fullname,
                  items: (filter) async => contacts!,
                  onChanged: (contact) => _selectedContact = contact?.id,
                ),
          ),

          const SizedBox(height: 16),
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
                ...tasks.map(
                  (t) => CheckboxListTile(
                    value: _selectedTasks.contains(t.id),
                    title: Text(t.name),
                    subtitle: Text(RichTextHelper.toPlainText(t.assumption)),
                    onChanged:
                        (on) => setState(() {
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
