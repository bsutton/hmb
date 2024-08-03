import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart'; // Import GoRouter
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
import '../../widgets/photo_gallery.dart';
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

    // Initialize task status correctly
    final initialTaskStatusId = widget.task?.taskStatusId ?? 1;
    June.getState(TaskStatusState.new).taskStatusId = initialTaskStatusId;

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
    return DaoPhoto().getByTask(widget.task!.id);
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

  Future<void> _showConfirmDeleteDialog(
          BuildContext context, Photo photo) async =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Photo'),
          content: ListBody(
            children: <Widget>[
              Image.file(File(photo.filePath),
                  width: 100, height: 100), // Thumbnail of the photo
              if (photo.comment.isNotEmpty) Text(photo.comment),
              const SizedBox(height: 10),
              const Text('Are you sure you want to delete this photo?'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                // Delete the photo from the database and the disk
                await DaoPhoto().delete(photo.id);
                await File(photo.filePath).delete();
                setState(() {
                  _photosFuture = _loadPhotos(); // Refresh the photos
                });
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      );

  Future<void> _showFullScreenPhoto(BuildContext context, String imagePath,
      String taskName, String comment) async {
    await context.push('/photo_viewer', extra: {
      'imagePath': imagePath,
      'taskName': taskName,
      'comment': comment,
    });
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
            _buildCheckList(task),

            HBMCrudTimeEntry(
              parentTitle: 'Task',
              parent: Parent(task),
            ),

            // Display photos and allow adding comments and deletion
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTakePhotoButton(task),
                _buildPhotoCRUD(),
              ],
            ),
          ],
        ),
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

  /// Build the take photo button
  Widget _buildTakePhotoButton(Task? task) => IconButton(
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
            await DaoPhoto().insert(newPhoto);
            setState(() {
              _photosFuture = _loadPhotos(); // Refresh the photos
            });
            PhotoGallery.notify();
          }
        },
      );

  /// Build the photo CRUD
  Widget _buildPhotoCRUD() => FutureBuilderEx<List<Photo>>(
      future: _photosFuture,
      builder: (context, photos) => Column(
        mainAxisSize: MainAxisSize.min,
            children: photos!
                .map((photo) => Column(
                  mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            Image.file(File(photo.filePath)),
                            Positioned(
                              right: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  // Fetch the task for this photo to get
                                  // the task name.
                                  final task =
                                      await DaoTask().getById(photo.taskId);
                                  if (context.mounted) {
                                    await _showFullScreenPhoto(
                                        context,
                                        photo.filePath,
                                        task!.name,
                                        photo.comment);
                                  }
                                },
                                child: Container(
                                  color: Colors.black.withOpacity(0.5),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(
                                    Icons.fullscreen,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        _buildCommentField(photo),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await _showConfirmDeleteDialog(context, photo);
                            PhotoGallery.notify();
                          },
                        ),
                      ],
                    ))
                .toList(),
          ));

  Widget _buildCommentField(Photo photo) {
    final _commentController = TextEditingController(text: photo.comment);
    final _commentFocusNode = FocusNode();

    _commentFocusNode.addListener(() async {
      if (!_commentFocusNode.hasFocus) {
        // Update the comment in the database when the text field loses focus
        photo.comment = _commentController.text;
        await DaoPhoto().update(photo);
        setState(() {
          // Photo comment updated in the database
        });
        PhotoGallery.notify();
      }
    });

    return TextField(
      controller: _commentController,
      focusNode: _commentFocusNode,
      decoration: const InputDecoration(labelText: 'Comment'),
      maxLines: null, // Allows the field to grow as needed
    );
  }

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
