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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:june/june.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../../dao/dao_task.dart';
import '../../../entity/entity.g.dart';
import '../../../util/flutter/platform_ex.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/help_button.dart';
import '../../widgets/hmb_crud_checklist_item.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../base_nested/edit_nested_screen.dart';
import 'photo_crud.dart';

class TaskEditScreen extends StatefulWidget {
  final Job job;
  final Task? task;

  late final BillingType billingType;

  TaskEditScreen({required this.job, super.key, this.task}) {
    // for the moment we don't let tasks override the billing type.
    billingType = job.billingType;
  }

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
  late TextEditingController _assumptionController;
  late PhotoController<Task> _photoController;
  late FocusNode _summaryFocusNode;
  late FocusNode _descriptionFocusNode;
  late FocusNode _assumptionFocusNode;

  @override
  Task? currentEntity;

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.task;

    _nameController = TextEditingController(text: currentEntity?.name);
    _descriptionController = TextEditingController(
      text: currentEntity?.description,
    );
    _assumptionController = TextEditingController(
      text: currentEntity?.assumption,
    );

    _photoController = PhotoController<Task>(
      parent: currentEntity,
      parentType: ParentType.task,
    );

    _summaryFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    _assumptionFocusNode = FocusNode();

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
    if (currentEntity?.status != null) {
      taskStatus = currentEntity?.status;
    }
    taskStatus ??= TaskStatus.awaitingApproval;

    setState(() {
      June.getState(SelectedTaskStatus.new).taskStatus = taskStatus;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _assumptionController.dispose();
    _photoController.dispose();
    _summaryFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _assumptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NestedEntityEditScreen<Task, Job>(
    entityName: 'Task',
    dao: DaoTask(),
    onInsert: (task, transaction) async {
      await _insertTask(task!, transaction);
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
        const SizedBox(height: 12),
        HMBTextArea(
          controller: _assumptionController,
          focusNode: _assumptionFocusNode,
          labelText: 'Assumptions',
        ).help(
          'Assumptions',
          '''Detail the assumptions your pricing is based on. Assumptions are shown on the Quote. ''',
        ),
        // _chooseBillingType(),
        _buildItemList(task),
        PhotoCrud<Task>(
          parentName: 'Task',
          parentType: ParentType.task,
          controller: _photoController,
        ),
      ],
    ),
  );

  Widget _buildItemList(Task? task) => Flexible(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [HMBCrudTaskItem(task: task)],
      ),
    ),
  );

  Widget _chooseTaskStatus(Task? task) => HMBDroplist<TaskStatus>(
    title: 'Task Status',
    selectedItem: () async => June.getState(SelectedTaskStatus.new).taskStatus,
    items: (filter) async => TaskStatus.getByFilter(filter),
    format: (item) => item.name,
    onChanged: (item) {
      setState(() {
        June.getState(SelectedTaskStatus.new).taskStatus = item;
      });
    },
  );

  Future<void> _insertTask(Task task, Transaction transaction) async {
    await DaoTask().insert(task, transaction);
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
      assumption: _assumptionController.text,
      status: June.getState(SelectedTaskStatus.new).taskStatus!,
    );
  }

  @override
  Future<Task> forInsert() async => Task.forInsert(
    jobId: widget.job.id,
    name: _nameController.text,
    description: _descriptionController.text,
    assumption: _assumptionController.text,
    status: June.getState(SelectedTaskStatus.new).taskStatus!,
  );

  @override
  void refresh() {
    setState(() {});
  }

  @override
  Future<void> postSave(Transaction transaction, Operation operation) async {}
}

class SelectedTaskStatus extends JuneState {
  TaskStatus? _taskStatus;

  TaskStatus? get taskStatus => _taskStatus;

  set taskStatus(TaskStatus? value) {
    _taskStatus = value;
    setState();
  }
}
