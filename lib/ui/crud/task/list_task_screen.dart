/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/format.dart';
import '../../dialog/dialog.g.dart';
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
            onDelete: onDelete,
            // ignore: discarded_futures
            onInsert: (task, transaction) =>
                DaoTask().insert(task, transaction),
            details: (task, details) => details == CardDetail.full
                ? _buildFullTasksDetails(task)
                : _buildTaskSummary(task),
            extended: widget.extended,
          ),
        ),
      ],
    );
  }

  Future<void> onDelete(Task? task) async {
    if (task == null) {
      return;
    }

    // if there is are any work assignment for this task then warn the user.
    final taskAssignments = await DaoWorkAssignmentTask().getByTask(task);
    if (taskAssignments.isEmpty) {
      await DaoTask().delete(task.id);
    } else {
      final message = StringBuffer()
        ..writeln(
          'Deleting this Task will affect the following Work Assignments',
        );
      final assignedTo = <String>[];
      for (final assignment in taskAssignments) {
        final workAssignment = await DaoWorkAssigment().getById(
          assignment.assignmentId,
        );
        if (workAssignment != null) {
          final supplier = await DaoSupplier().getById(
            workAssignment.supplierId,
          );
          if (supplier != null) {
            assignedTo.add(supplier.name);
            message.writeln('${supplier.name} #${workAssignment.id}');
          }
        }
      }
      if (mounted) {
        await askUserToContinue(
          context: context,
          title: 'Task is assigned to Work Assignment',
          message: message.toString(),
          yesLabel: 'Continue?',
          noLabel: 'Cancel',
          onConfirmed: () async {
            await DaoTask().delete(task.id);
          },
        );
      }
    }
  }

  Future<List<Task>> _fetchTasks() async {
    final showCompleted = June.getState(
      ShowCompletedTasksState.new,
    )._showCompletedTasks;
    final tasks = await DaoTask().getTasksByJob(widget.parent.parent!.id);

    final included = <Task>[];
    for (final task in tasks) {
      final status = task.status;
      final complete = status.isComplete();
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
      Text(task.status.name),
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
          June.getState(SelectJobStatus.new).jobStatusId = job.jobStatusId;
        },
      ),
    ],
  );

  Column _buildTaskSummary(Task task) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(task.status.name),
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
          June.getState(SelectJobStatus.new).jobStatusId = job.jobStatusId;
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
    setState(); // Notify listeners to rebuild
  }
}
