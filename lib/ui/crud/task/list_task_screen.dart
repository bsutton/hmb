import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../dao/dao_photo.dart'; // Import the Photo DAO
import '../../../dao/dao_task.dart';
import '../../../dao/dao_task_status.dart';
import '../../../dao/dao_time_entry.dart';
import '../../../entity/job.dart';
import '../../../entity/task.dart';
import '../../../entity/time_entry.dart';
import '../../../util/format.dart';
import '../../widgets/hmb_start_time_entry.dart';
import '../../widgets/hmb_toggle.dart';
import '../../widgets/text/hmb_text.dart';
import '../base_nested/list_nested_screen.dart';
import '../job/edit_job_screen.dart';
import 'edit_task_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({
    required this.parent,
    required this.extended,
    super.key,
  });
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
    final showCompleted = June.getState(
      ShowCompletedTasksState.new,
    )._showCompletedTasks;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: NestedEntityListScreen<Task, Job>(
            key: ValueKey(showCompleted),
            parent: widget.parent,
            parentTitle: 'Job',
            entityNamePlural: 'Tasks',
            entityNameSingular: 'Task',
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
                  initialValue: June.getState(
                    ShowCompletedTasksState.new,
                  )._showCompletedTasks,
                  onToggled: (value) {
                    setState(() {
                      June.getState(ShowCompletedTasksState.new).toggle();
                    });
                  },
                ),
              ],
            ),
            onEdit: (task) =>
                TaskEditScreen(job: widget.parent.parent!, task: task),
            // ignore: discarded_futures
            onDelete: (task) => DaoTask().delete(task!.id),
            // ignore: discarded_futures
            onInsert: (task, transaction) =>
                DaoTask().insert(task!, transaction),
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
    final showCompleted = June.getState(
      ShowCompletedTasksState.new,
    )._showCompletedTasks;
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
        builder: (context, status) => Text(status?.name ?? 'Not Set'),
      ),
      FutureBuilderEx(
        future: DaoTask()
            // ignore: discarded_futures
            .getAccruedValueForTask(task: task, includeBilled: true),
        builder: (context, taskAccruedValue) => Row(
          children: [
            HMBText(
              'Effort(hrs): ${taskAccruedValue!.earnedLabourHours.format('0.00')}/${taskAccruedValue.taskEstimatedValue.estimatedLabourHours.format('0.00')}',
            ),
            HMBText(
              ' Earnings: ${taskAccruedValue.earnedMaterialCharges}/${taskAccruedValue.taskEstimatedValue.estimatedMaterialsCharge}',
            ),
          ],
        ),
      ),
      HMBStartTimeEntry(
        task: task,
        onStart: (job) {
          June.getState(SelectJobStatus.new)
            ..jobStatusId = job.jobStatusId
            ..setState();
        },
      ),
    ],
  );

  Column _buildTaskSummary(Task task) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FutureBuilderEx(
        // ignore: discarded_futures
        future: DaoTaskStatus().getById(task.taskStatusId),
        builder: (context, status) => Text(status?.name ?? 'Not Set'),
      ),
      FutureBuilderEx(
        // ignore: discarded_futures
        future: DaoTimeEntry().getByTask(task.id),
        builder: (context, timeEntries) => Text(
          formatDuration(
            timeEntries!.fold<Duration>(
              Duration.zero,
              (a, b) => a + b.duration,
            ),
          ),
        ),
      ),
      FutureBuilderEx<int>(
        // ignore: discarded_futures
        future: _getPhotoCount(task.id),
        builder: (context, photoCount) => Text('Photos: ${photoCount ?? 0}'),
      ), // Display photo count
      HMBStartTimeEntry(
        task: task,
        onStart: (job) {
          June.getState(SelectJobStatus.new)
            ..jobStatusId = job.jobStatusId
            ..setState();
        },
      ),
    ],
  );

  Future<int> _getPhotoCount(int taskId) async =>
      (await DaoPhoto().getByParent(taskId, ParentType.task)).length;
}

class ShowCompletedTasksState extends JuneState {
  var _showCompletedTasks = false;

  void toggle() {
    _showCompletedTasks = !_showCompletedTasks;
    refresh(); // Notify listeners to rebuild
  }
}
