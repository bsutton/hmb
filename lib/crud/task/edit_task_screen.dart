import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:money2/money2.dart';

import '../../dao/dao_checklist.dart';
import '../../dao/dao_checklist_item.dart';
import '../../dao/dao_task.dart';
import '../../dao/dao_task_status.dart';
import '../../dao/join_adaptors/join_adaptor_check_list_item.dart';
import '../../entity/check_list.dart';
import '../../entity/job.dart';
import '../../entity/task.dart';
import '../../entity/task_status.dart';
import '../../util/money_ex.dart';
import '../../util/platform_ex.dart';
import '../../widgets/hmb_crud_checklist_item.dart';
import '../../widgets/hmb_crud_time_entry.dart';
import '../../widgets/hmb_droplist.dart';
import '../../widgets/hmb_text.dart';
import '../../widgets/hmb_text_area.dart';
import '../../widgets/hmb_text_field.dart';
import '../base_nested/edit_nested_screen.dart';
import '../base_nested/list_nested_screen.dart';
import 'photo_crud.dart';

class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({required this.job, super.key, this.task});
  final Job job;
  final Task? task;

  @override
  // ignore: library_private_types_in_public_api
  _TaskEditScreenState createState() => _TaskEditScreenState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Task?>('task', task));
  }
}

class _TaskEditScreenState extends State<TaskEditScreen>
    implements NestedEntityState<Task> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late PhotoController _photoController;
  late FocusNode _summaryFocusNode;
  late FocusNode _descriptionFocusNode;

  BillingType _selectedBillingType = BillingType.timeAndMaterial;

  Fixed _totalEffortInHours = Fixed.zero;
  Money _totalMaterialsCost = MoneyEx.zero;
  Money _totalToolsCost = MoneyEx.zero;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.task?.name);
    _descriptionController =
        TextEditingController(text: widget.task?.description);

    _photoController = PhotoController(task: widget.task);

    _summaryFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();

    _selectedBillingType = widget.task?.billingType ?? widget.job.billingType;

    // ignore: discarded_futures
    _calculateChecklistSummary(); // Calculate the effort/cost based on checklist items

    if (isNotMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_summaryFocusNode);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _photoController.dispose();
    _summaryFocusNode.dispose();
    _descriptionFocusNode.dispose();
  }

  @override
  Widget build(BuildContext context) => NestedEntityEditScreen<Task, Job>(
        entity: widget.task,
        entityName: 'Task',
        dao: DaoTask(),
        onInsert: (task) async {
          await _insertTask(task!);
        },
        entityState: this,
        editor: (task) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HMBTextField(
              controller: _nameController,
              focusNode: _summaryFocusNode,
              labelText: 'Summary',
              required: true,
            ),
            _chooseTaskStatus(task),
            HMBTextArea(
              controller: _descriptionController,
              focusNode: _descriptionFocusNode,
              labelText: 'Description',
            ),
            _chooseBillingType(),

            // Display the summary based on billing type
            if (_selectedBillingType == BillingType.timeAndMaterial)
              _buildEffortSummary(), // Display effort summary
            if (_selectedBillingType == BillingType.fixedPrice)
              _buildCostSummary(), // Display cost summary

            _buildCheckList(task),
            HBMCrudTimeEntry(
              parentTitle: 'Task',
              parent: Parent(task),
            ),
            PhotoCrud(controller: _photoController),
          ],
        ),
      );

  Widget _chooseBillingType() => HMBDroplist<BillingType>(
        title: 'Billing Type',
        items: (filter) async => BillingType.values,
        initialItem: () async => _selectedBillingType,
        onChanged: (billingType) => setState(() {
          _selectedBillingType = billingType!;
          // ignore: lines_longer_than_80_chars, discarded_futures
          _calculateChecklistSummary(); // Recalculate the summary when billing type changes
        }),
        format: (value) => value.display,
      );

  // Calculate the checklist summary for effort or cost
  Future<void> _calculateChecklistSummary() async {
    final checkListItems = await DaoCheckListItem().getByTask(widget.task!.id);
    _totalEffortInHours = Fixed.zero;
    _totalMaterialsCost = MoneyEx.zero;
    _totalToolsCost = MoneyEx.zero;

    for (final item in checkListItems) {
      switch (item.itemTypeId) {
        case 5: // Action (Effort)
          _totalEffortInHours += item.estimatedLabour;
        case 1: // Materials - buy
          _totalMaterialsCost += item.estimatedMaterialCost
              .multiplyByFixed(item.estimatedMaterialQuantity);
        case 3: // Tools - buy
          _totalToolsCost += item.estimatedMaterialCost
              .multiplyByFixed(item.estimatedMaterialQuantity);
      }
    }

    setState(() {}); // Update the UI with the calculated summary
  }

  // Build the summary for effort (time and materials billing)
  Widget _buildEffortSummary() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HMBText('Total Effort: $_totalEffortInHours hours', bold: true),
        ],
      );

  // Build the summary for cost (fixed price billing)
  Widget _buildCostSummary() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HMBText('Total Materials Cost: $_totalMaterialsCost'),
          HMBText('Total Tools Cost: $_totalToolsCost'),
        ],
      );

  FutureBuilderEx<CheckList?> _buildCheckList(Task? task) =>
      FutureBuilderEx<CheckList?>(
          // ignore: discarded_futures
          future: DaoCheckList().getByTask(task?.id),
          builder: (context, checklist) => Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HBMCrudCheckListItem<CheckList>(
                        parent: Parent(checklist),
                        daoJoin: JoinAdaptorCheckListCheckListItem(),
                      ),
                    ],
                  ),
                ),
              ));

  Widget _chooseTaskStatus(Task? task) => HMBDroplist<TaskStatus>(
      title: 'Task Status',
      initialItem: () async => DaoTaskStatus().getById(task?.taskStatusId ??
          June.getState(SelectedTaskStatus.new).taskStatusId),
      items: (filter) async => DaoTaskStatus().getByFilter(filter),
      format: (item) => item.name,
      onChanged: (item) {
        June.getState(SelectedTaskStatus.new).taskStatusId = item?.id;
      });

  Future<void> _insertTask(Task task) async {
    await DaoTask().insert(task);
    final newChecklist = CheckList.forInsert(
        name: 'default',
        description: 'Default Checklist',
        listType: CheckListType.owned);
    await DaoCheckList().insertForTask(newChecklist, task);

    _photoController.task = task;
  }

  @override
  Future<Task> forUpdate(Task task) async {
    await _photoController.save();
    return Task.forUpdate(
      entity: task,
      jobId: widget.job.id,
      name: _nameController.text,
      description: _descriptionController.text,
      taskStatusId: June.getState(SelectedTaskStatus.new).taskStatusId!,
      billingType: _selectedBillingType, // Retain the selected billing type
    );
  }

  @override
  Future<Task> forInsert() async => Task.forInsert(
        jobId: widget.job.id,
        name: _nameController.text,
        description: _descriptionController.text,
        taskStatusId: June.getState(SelectedTaskStatus.new).taskStatusId!,
        billingType: _selectedBillingType, // Retain the selected billing type
      );

  @override
  void refresh() {
    setState(() {});
  }
}

class SelectedTaskStatus {
  SelectedTaskStatus();

  int? taskStatusId;
}
