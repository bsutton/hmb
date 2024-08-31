import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_checklist.dart';
import '../../dao/dao_task.dart';
import '../../dao/dao_task_status.dart';
import '../../dao/join_adaptors/join_adaptor_check_list_item.dart';
import '../../entity/check_list.dart';
import '../../entity/job.dart';
import '../../entity/task.dart';
import '../../entity/task_status.dart';
import '../../util/fixed_ex.dart';
import '../../util/money_ex.dart';
import '../../util/platform_ex.dart';
import '../../widgets/hmb_crud_checklist_item.dart';
import '../../widgets/hmb_crud_time_entry.dart';
import '../../widgets/hmb_droplist.dart';
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
  late TextEditingController _estimatedCostController;
  late TextEditingController _effortInHoursController;
  late PhotoController _photoController;
  late FocusNode _summaryFocusNode;
  late FocusNode _descriptionFocusNode;
  late FocusNode _costFocusNode;
  late FocusNode _estimatedCostFocusNode;
  late FocusNode _effortInHoursFocusNode;
  late FocusNode _itemTypeIdFocusNode;

  BillingType _selectedBillingType = BillingType.timeAndMaterial;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.task?.name);
    _descriptionController =
        TextEditingController(text: widget.task?.description);
    _estimatedCostController =
        TextEditingController(text: widget.task?.estimatedCost.toString());
    _effortInHoursController =
        TextEditingController(text: widget.task?.effortInHours.toString());

    _photoController = PhotoController(task: widget.task);

    _summaryFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    _costFocusNode = FocusNode();
    _estimatedCostFocusNode = FocusNode();
    _effortInHoursFocusNode = FocusNode();
    _itemTypeIdFocusNode = FocusNode();

    _selectedBillingType = widget.task?.billingType ?? widget.job.billingType;

    final initialTaskStatusId = widget.task?.taskStatusId ?? 1;
    June.getState(SelectedTaskStatus.new).taskStatusId = initialTaskStatusId;

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
    _estimatedCostController.dispose();
    _effortInHoursController.dispose();
    _photoController.dispose();
    _summaryFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _costFocusNode.dispose();
    _estimatedCostFocusNode.dispose();
    _effortInHoursFocusNode.dispose();
    _itemTypeIdFocusNode.dispose();
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
            HMBTextField(
              controller: _estimatedCostController,
              focusNode: _estimatedCostFocusNode,
              labelText: 'Estimated Cost',
              keyboardType: TextInputType.number,
            ),
            HMBTextField(
              controller: _effortInHoursController,
              focusNode: _effortInHoursFocusNode,
              labelText: 'Effort (decimal hours)',
              keyboardType: TextInputType.number,
            ),
            _chooseBillingType(), // Add this line

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
        }),
        format: (value) => value.display,
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
      estimatedCost: MoneyEx.tryParse(_estimatedCostController.text),
      effortInHours: FixedEx.tryParse(_effortInHoursController.text),
      taskStatusId: June.getState(SelectedTaskStatus.new).taskStatusId!,
      billingType: _selectedBillingType, // Add this line
    );
  }

  @override
  Future<Task> forInsert() async => Task.forInsert(
        jobId: widget.job.id,
        name: _nameController.text,
        description: _descriptionController.text,
        estimatedCost: MoneyEx.tryParse(_estimatedCostController.text),
        effortInHours: FixedEx.tryParse(_effortInHoursController.text),
        taskStatusId: June.getState(SelectedTaskStatus.new).taskStatusId!,
        billingType: _selectedBillingType, // Add this line
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
