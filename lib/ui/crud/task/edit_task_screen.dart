import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_photo.dart';
import '../../../dao/dao_task.dart';
import '../../../dao/dao_task_status.dart';
import '../../../entity/job.dart';
import '../../../entity/task.dart';
import '../../../entity/task_status.dart';
import '../../../util/platform_ex.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_crud_checklist_item.dart';
import '../../widgets/hmb_crud_time_entry.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../base_nested/edit_nested_screen.dart';
import '../base_nested/list_nested_screen.dart';
import 'photo_crud.dart';

class TaskEditScreen extends StatefulWidget {
  TaskEditScreen({required this.job, super.key, this.task}) {
    billingType = job.billingType;
  }
  final Job job;
  final Task? task;

  /// for the moment we don't let tasks override
  /// the billing type.
  late final BillingType billingType;

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
  late PhotoController<Task> _photoController;
  late FocusNode _summaryFocusNode;
  late FocusNode _descriptionFocusNode;

  @override
  Task? currentEntity;

  // BillingType _selectedBillingType = BillingType.timeAndMaterial;

  // Fixed _totalEffortInHours = Fixed.zero;
  // Money _totalMaterialsCost = MoneyEx.zero;
  // Money _totalToolsCost = MoneyEx.zero;

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.task;

    _nameController = TextEditingController(text: currentEntity?.name);
    _descriptionController =
        TextEditingController(text: currentEntity?.description);

    _photoController = PhotoController<Task>(
        parent: currentEntity, parentType: ParentType.task);

    _summaryFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();

    // _selectedBillingType = currentEntity?.billingType ?? widget.job.billingType;

    // ignore: discarded_futures
    // _calculateChecklistSummary(); // Calculate the effort/cost based on checklist items

    if (isNotMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_summaryFocusNode);
      });
    }

    // ignore: discarded_futures
    _loadInitialTaskStatus();
  }

  Future<void> _loadInitialTaskStatus() async {
    TaskStatus? taskStatus;
    if (currentEntity?.taskStatusId != null) {
      taskStatus = await DaoTaskStatus().getById(currentEntity!.taskStatusId);
    }

    taskStatus ??= await DaoTaskStatus().getByEnum(TaskStatusEnum.preApproval);

    setState(() {
      June.getState(SelectedTaskStatus.new).taskStatus = taskStatus;
    });
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
            // _chooseBillingType(),

            // Display the summary based on billing type
            // if (_selectedBillingType == BillingType.timeAndMaterial)
            //   _buildEffortSummary(), // Display effort summary
            // if (_selectedBillingType == BillingType.fixedPrice)
            //   _buildCostSummary(), // Display cost summary

            _buildItemList(task),
            HBMCrudTimeEntry(
              parentTitle: 'Task',
              parent: Parent(task),
            ),
            PhotoCrud<Task>(
                parentName: 'Task',
                parentType: ParentType.task,
                controller: _photoController),
          ],
        ),
      );

  // Widget _chooseBillingType() => HMBDroplist<BillingType>(
  //       title: 'Billing Type',
  //       items: (filter) async => BillingType.values,
  //       selectedItem: () async => _selectedBillingType,
  //       onChanged: (billingType) => setState(() {
  //         _selectedBillingType = billingType;
  //         // ignore: lines_longer_than_80_chars, discarded_futures
  //         _calculateChecklistSummary(); // Recalculate the summary when billing type changes
  //       }),
  //       format: (value) => value.display,
  //     );

  // // Calculate the checklist summary for effort or cost
  // Future<void> _calculateChecklistSummary() async {
  //   // _totalEffortInHours = Fixed.zero;
  //   // _totalMaterialsCost = MoneyEx.zero;
  //   // _totalToolsCost = MoneyEx.zero;

  //   if (currentEntity == null) {
  //     return;
  //   }
  //   final taskItems = await DaoTaskItem().getByTask(currentEntity!.id);

  //   for (final item in taskItems) {
  //     switch (item.itemTypeId) {
  //       case 5: // Labour (Effort)
  //         _totalEffortInHours += item.estimatedLabourHours!;
  //       case 1: // Materials - buy
  //         _totalMaterialsCost += item.estimatedMaterialUnitCost!
  //             .multiplyByFixed(item.estimatedMaterialQuantity!);
  //       case 3: // Tools - buy
  //         _totalToolsCost += item.estimatedMaterialUnitCost!
  //             .multiplyByFixed(item.estimatedMaterialQuantity!);
  //     }
  //   }

  //   setState(() {}); // Update the UI with the calculated summary
  // }

  // Build the summary for effort (time and materials billing)
  // Widget _buildEffortSummary() => Column(
  //       crossAxisAlignment: CrossAxisAlignment.stretch,
  //       children: [
  //         HMBText('Total Effort: $_totalEffortInHours hours', bold: true),
  //       ],
  //     );

  // // Build the summary for cost (fixed price billing)
  // Widget _buildCostSummary() => Column(
  //       crossAxisAlignment: CrossAxisAlignment.stretch,
  //       children: [
  //         HMBText('Total Materials Cost: $_totalMaterialsCost'),
  //         HMBText('Total Tools Cost: $_totalToolsCost'),
  //       ],
  //     );

  Widget _buildItemList(Task? task) => Flexible(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HMBCrudTaskItem(
                task: task,
              ),
            ],
          ),
        ),
      );

  Widget _chooseTaskStatus(Task? task) => HMBDroplist<TaskStatus>(
        title: 'Task Status',
        selectedItem: () async =>
            June.getState(SelectedTaskStatus.new).taskStatus,
        items: (filter) async => DaoTaskStatus().getByFilter(filter),
        format: (item) => item.name,
        onChanged: (item) {
          setState(() {
            June.getState(SelectedTaskStatus.new).taskStatus = item;
          });
        },
      );

  Future<void> _insertTask(Task task) async {
    await DaoTask().insert(task);

    _photoController.parent = task;
  }

  @override
  Future<Task> forUpdate(Task task) async {
    await _photoController.save();
    return Task.forUpdate(
      entity: task,
      jobId: widget.job.id,
      name: _nameController.text,
      description: _descriptionController.text,
      taskStatusId: June.getState(SelectedTaskStatus.new).taskStatus!.id,
      // billingType: _selectedBillingType, // Retain the selected billing type
    );
  }

  @override
  Future<Task> forInsert() async => Task.forInsert(
        jobId: widget.job.id,
        name: _nameController.text,
        description: _descriptionController.text,
        taskStatusId: June.getState(SelectedTaskStatus.new).taskStatus!.id,
        // billingType: _selectedBillingType, // Retain the selected billing type
      );

  @override
  void refresh() {
    setState(() {});
  }
}

class SelectedTaskStatus {
  SelectedTaskStatus();

  TaskStatus? taskStatus;
}
