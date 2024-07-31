import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:image_picker/image_picker.dart';
import 'package:june/june.dart';
import 'package:path_provider/path_provider.dart';

import '../../dao/dao_checklist.dart';
import '../../dao/dao_photo.dart'; // Import the Photo DAO
import '../../dao/dao_task.dart';
import '../../dao/dao_task_status.dart';
import '../../dao/join_adaptors/join_adaptor_check_list_item.dart';
import '../../entity/check_list.dart';
import '../../entity/job.dart';
import '../../entity/photo.dart'; // Import the Photo entity
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
  late Future<List<Photo>> _photosFuture; // Future to load photos

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

    // Load photos associated with the task
    // ignore: discarded_futures
    _photosFuture = _loadPhotos();
  }

  Future<List<Photo>> _loadPhotos() async {
    if (widget.task == null) {
      return [];
    }
    return PhotoDao().getPhotosByTaskId(widget.task!.id);
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

  Future<File?> takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) {
      return null;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = pickedFile.path.split('/').last;
    final savedImage =
        await File(pickedFile.path).copy('${appDir.path}/$fileName');

    return savedImage;
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

            // Display photos and allow adding comments and deletion
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () async {
                    final photoFile = await takePhoto();
                    if (photoFile != null) {
                      // Insert the photo metadata into the database
                      final newPhoto = Photo.forInsert(
                        taskId: task!.id,
                        filePath: photoFile.path,
                        comment: '',
                      );
                      await PhotoDao().insert(newPhoto);
                      setState(() {
                        _photosFuture = _loadPhotos(); // Refresh the photos
                      });
                    }
                  },
                ),
                FutureBuilderEx<List<Photo>>(
                    future: _photosFuture,
                    builder: (context, photos) => Column(
                          children: [
                            for (final photo in photos!)
                              Column(
                                children: [
                                  Image.file(File(photo.filePath)),
                                  TextField(
                                    controller: TextEditingController(
                                        text: photo.comment),
                                    decoration: const InputDecoration(
                                        labelText: 'Comment'),
                                    onSubmitted: (newComment) async {
                                      await PhotoDao().update(photo);
                                      setState(() {
                                        photo.comment = newComment;
                                        // Update the photo comment in 
                                        // the database
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      // Delete the photo from the database
                                      // and the disk
                                      await PhotoDao().delete(photo.id);
                                      setState(() {
                                        File(photo.filePath).delete();
                                        _photosFuture =
                                            _loadPhotos(); // Refresh the photos
                                      });
                                    },
                                  ),
                                ],
                              ),
                          ],
                        )),
              ],
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
    // ignore: discarded_futures
    _photosFuture = _loadPhotos(); // Refresh photos when screen is refreshed
    setState(() {});
  }
}

class TaskStatusState {
  TaskStatusState();

  int? taskStatusId;
}
