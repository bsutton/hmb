import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../dao/dao_photo.dart'; // Import the Photo DAO
import '../../dao/dao_task.dart';
import '../../dao/dao_task_status.dart';
import '../../dao/dao_time_entry.dart';
import '../../entity/job.dart';
import '../../entity/task.dart';
import '../../entity/time_entry.dart';
import '../../util/format.dart';
import '../../widgets/hmb_start_time_entry.dart';
import '../../widgets/hmb_toggle.dart';
import '../../widgets/text/hmb_text.dart';
import '../base_nested/list_nested_screen.dart';
import 'edit_task_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen(
      {required this.parent, required this.extended, super.key});
  final Parent<Job> parent;
  final bool extended;

  @override
  // ignore: library_private_types_in_public_api
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  /// If a time is running for a task, this will be the
  /// active TimeEntry record.
  /// Only a single task can have a time running at a time.
  late Future<TimeEntry?> activeTimeEntry;

  @override
  void initState() {
    // ignore: discarded_futures
    activeTimeEntry = DaoTimeEntry().getActiveEntry();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final showCompleted =
        June.getState(ShowCompletedTasksState.new).showCompletedTasks;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: NestedEntityListScreen<Task, Job>(
            key: ValueKey(showCompleted),
            parent: widget.parent,
            entityNamePlural: 'Tasks',
            entityNameSingular: 'Task',
            parentTitle: 'Job',
            dao: DaoTask(),
            // ignore: discarded_futures
            fetchList: _fetchTasks,
            title: (entity) => Text(entity.name),
            filterBar: (entity) => Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                HMBToggle(
                  label: 'Show Completed',
                  tooltip: showCompleted
                      ? 'Show Only Non-Completed Tasks'
                      : 'Show Completed Tasks',
                  initialValue: June.getState(ShowCompletedTasksState.new)
                      .showCompletedTasks,
                  onChanged: (value) {
                    setState(() {
                      June.getState(ShowCompletedTasksState.new).toggle();
                    });
                  },
                ),
              ],
            ),
            onEdit: (task) =>
                TaskEditScreen(job: widget.parent.parent!, task: task),
            onDelete: (task) async => DaoTask().delete(task!.id),
            onInsert: (task) async => DaoTask().insert(task!),
            details: (task, details) => details == CardDetail.full
                ? _buildFullTasksDetails(task)
                : _buildTaskSummary(task),
            extended: widget.extended,
          ),
        ),
      ],
    );
  }

  Future<List<Task>> _fetchTasks() async {
    final showCompleted =
        June.getState(ShowCompletedTasksState.new).showCompletedTasks;
    final tasks = await DaoTask().getTasksByJob(widget.parent.parent!.id);

    final included = <Task>[];
    for (final task in tasks) {
      final status = await DaoTaskStatus().getById(task.taskStatusId);
      final complete = status?.isComplete() ?? false;
      if ((showCompleted && complete) || (!showCompleted && !complete)) {
        included.add(task);
      }
    }
    return included;
  }

  Column _buildFullTasksDetails(Task task) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoTaskStatus().getById(task.taskStatusId),
              builder: (context, status) => Text(status?.name ?? 'Not Set')),
          FutureBuilderEx(
            // ignore: discarded_futures
            future: DaoTask().getAccruedValue(task: task, includeBilled: true),
            builder: (context, taskAccruedValue) => Row(
              children: [
                HMBText(
                    'Effort(hrs): ${taskAccruedValue!.earnedLabour.format('0.00')}/${taskAccruedValue.taskEstimatedValue.estimatedLabour.format('0.00')}'),
                HMBText(
                    ' Earnings: ${taskAccruedValue.earnedMaterialCharges}/${taskAccruedValue.taskEstimatedValue.estimatedMaterialsCharge}')
              ],
            ),
          ),
          HMBStartTimeEntry(task: task)
        ],
      );

  Column _buildTaskSummary(Task task) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoTaskStatus().getById(task.taskStatusId),
              builder: (context, status) => Text(status?.name ?? 'Not Set')),
          FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoTimeEntry().getByTask(task.id),
              builder: (context, timeEntries) => Text(formatDuration(
                  timeEntries!.fold<Duration>(
                      Duration.zero, (a, b) => a + b.duration)))),
          FutureBuilderEx<int>(
              // ignore: discarded_futures
              future: _getPhotoCount(task.id),
              builder: (context, photoCount) =>
                  Text('Photos: ${photoCount ?? 0}')), // Display photo count
          HMBStartTimeEntry(task: task)
        ],
      );

  Future<int> _getPhotoCount(int taskId) async =>
      (await DaoPhoto().getByTask(taskId)).length;
}

class ShowCompletedTasksState extends JuneState {
  bool showCompletedTasks = false;

  void toggle() {
    showCompletedTasks = !showCompletedTasks;
    refresh(); // Notify listeners to rebuild
  }
}
