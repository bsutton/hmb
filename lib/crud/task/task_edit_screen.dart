import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

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
import '../base_nested/nested_edit_screen.dart';
import '../base_nested/nested_list_screen.dart';

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
  late FocusNode _summaryFocusNode;
  late FocusNode _descriptionFocusNode;
  late FocusNode _costFocusNode;
  late FocusNode _estimatedCostFocusNode;
  late FocusNode _effortInHoursFocusNode;
  late FocusNode _itemTypeIdFocusNode;
  // late Future<CheckList?> _checkListFuture;

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


    _summaryFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    _costFocusNode = FocusNode();
    _estimatedCostFocusNode = FocusNode();
    _effortInHoursFocusNode = FocusNode();
    _itemTypeIdFocusNode = FocusNode();

    June.getState(TaskStatusState.new).taskStatusId = widget.task?.id ?? 1;

    if (isNotMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_summaryFocusNode);
      });
    }

    // _checkListFuture = _loadOrCreateCheckList();
  }

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _estimatedCostController.dispose();
    _effortInHoursController.dispose();
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
        onInsert: (task) async => _insertTaskWithCheckList(task!),
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

            /// Direct Check List
            FutureBuilderEx<CheckList?>(
                // ignore: discarded_futures
                future: DaoCheckList().getByTask(task?.id),
                builder: (context, checklist) => Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            HBMCrudCheckListItem<CheckList>(
                              parent: Parent(checklist),
                              daoJoin: JoinAdaptorCheckListCheckListItem(),
                            ),
                          ],
                        ),
                      ),
                    )),

            HBMCrudTimeEntry(
              parentTitle: 'Task',
              parent: Parent(task),
            ),
          ],
        ),
      );

  Widget _chooseTaskStatus(Task? task) => HMBDroplist<TaskStatus>(
      title: 'Task Status',
      initialItem: () async => DaoTaskStatus().getById(task?.taskStatusId ?? 1),
      items: (filter) async => DaoTaskStatus().getByFilter(filter),
      format: (item) => item.name,
      onChanged: (item) {
        June.getState(TaskStatusState.new).taskStatusId = item.id;
      });

  Future<void> _insertTaskWithCheckList(Task task) async {
    await DaoTask().insert(task);
    final newChecklist = CheckList.forInsert(
        name: 'default',
        description: 'Default Checklist',
        listType: CheckListType.owned);
    await DaoCheckList().insertForTask(newChecklist, task);
  }

  // Future<CheckList?> _loadOrCreateCheckList() async {
  //   if (widget.task == null) {
  //     return null;
  //   }
  //   final checklists = await DaoCheckList().getByTask(widget.task!.id);
  //   if (checklists == null) {
  //     return null;
  //   } else {
  //     final newChecklist = CheckList.forInsert(
  //         name: 'default',
  //         description: 'Default Task Checklist',
  //         listType: CheckListType.owned);
  //     await DaoCheckList().insert(newChecklist);
  //     return newChecklist;
  //   }
  // }

  @override
  Future<Task> forUpdate(Task task) async => Task.forUpdate(
      entity: task,
      jobId: widget.job.id,
      name: _nameController.text,
      description: _descriptionController.text,
      estimatedCost: MoneyEx.tryParse(_estimatedCostController.text),
      effortInHours: FixedEx.tryParse(_effortInHoursController.text),
      taskStatusId: June.getState(TaskStatusState.new).taskStatusId!);

  @override
  Future<Task> forInsert() async => Task.forInsert(
      jobId: widget.job.id,
      name: _nameController.text,
      description: _descriptionController.text,
      estimatedCost: MoneyEx.tryParse(_estimatedCostController.text),
      effortInHours: FixedEx.tryParse(_effortInHoursController.text),
      taskStatusId: June.getState(TaskStatusState.new).taskStatusId!);

  @override
  void refresh() {
    setState(() {
      // _checkListFuture = _loadOrCreateCheckList();
    });
  }
}

class TaskStatusState {
  TaskStatusState();

  int? taskStatusId;
}
