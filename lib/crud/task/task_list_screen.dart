import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_task.dart';
import '../../dao/dao_task_status.dart';
import '../../dao/dao_time_entry.dart';
import '../../entity/job.dart';
import '../../entity/task.dart';
import '../../entity/time_entry.dart';
import '../../util/format.dart';
import '../../widgets/hmb_start_time_entry.dart';
import '../../widgets/hmb_text.dart';
import '../base_nested/nested_list_screen.dart';
import '../task/task_edit_screen.dart';

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
  Widget build(BuildContext context) => NestedEntityListScreen<Task, Job>(
        parent: widget.parent,
        entityNamePlural: 'Tasks',
        entityNameSingular: 'Task',
        parentTitle: 'Job',
        dao: DaoTask(),
        // ignore: discarded_futures
        fetchList: () => DaoTask().getTasksByJob(widget.parent.parent!),
        title: (entity) => Text(entity.name),
        onEdit: (task) =>
            TaskEditScreen(job: widget.parent.parent!, task: task),
        onDelete: (task) async => DaoTask().delete(task!.id),
        onInsert: (task) async => DaoTask().insert(task!),
        details: (task, details) => details == CardDetail.full
            ? _buildFullTasksDetails(task)
            : _buildTaskSummary(task),
        extended: widget.extended,
      );

  Column _buildFullTasksDetails(Task task) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoTaskStatus().getById(task.taskStatusId),
              builder: (context, status) => Text(status?.name ?? 'Not Set')),
          FutureBuilderEx(
            // ignore: discarded_futures
            future: DaoTask().getTaskStatistics(task),
            builder: (context, taskStatistics) => Row(
              children: [
                HMBText(
                    'Effort(hrs): ${taskStatistics!.completedEffort.format('0.00')}/${taskStatistics.totalEffort.format('0.00')}'),
                HMBText(
                    ' Earnings: ${taskStatistics.earnedCost}/${taskStatistics.totalCost}')
              ],
            ),
          ),
          HMBStartTimeEntry(task: task)
        ],
      );

  Column _buildTaskSummary(Task task) => Column(
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
          HMBStartTimeEntry(task: task)
        ],
      );
}
