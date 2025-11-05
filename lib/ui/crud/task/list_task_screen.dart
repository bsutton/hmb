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

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../dialog/dialog.g.dart';
import '../../widgets/hmb_toggle.dart';
import '../../widgets/layout/layout.g.dart';
import '../base_full_screen/list_entity_screen.dart';
import '../base_nested/list_nested_screen.dart';
import 'edit_task_screen.dart';
import 'list_task_card.dart';

class TaskListScreen extends StatefulWidget {
  final Parent<Job> parent;
  final bool extended;

  const TaskListScreen({
    required this.parent,
    required this.extended,
    super.key,
  });

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
      ShowInActiveTasksState.new,
    )._showInActiveTasks;
    return HMBColumn(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: EntityListScreen<Task>(
            entityNameSingular: 'Task',
            entityNamePlural: 'Tasks',
            key: ValueKey(showCompleted),
            dao: DaoTask(),
            // ignore: discarded_futures
            fetchList: _fetchTasks,
            listCardTitle: (entity) => Text(entity.name),

            /// all filter modes exclude some data.
            isFilterActive: () => true,
            filterSheetBuilder: (entity) => Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                HMBToggle(
                  label: 'Show Inactive',
                  hint: showCompleted
                      ? 'Show Only Active Tasks'
                      : 'Show Inactive Tasks',
                  initialValue: June.getState(
                    ShowInActiveTasksState.new,
                  )._showInActiveTasks,
                  onToggled: (value) {
                    setState(() {
                      June.getState(ShowInActiveTasksState.new).toggle();
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
            listCard: _buildFullTasksDetails,
            // : _buildTaskSummary(task),
          ),
        ),
      ],
    );
  }

  Future<bool> onDelete(Task task) async {
    // if there is are any work assignment for this task then warn the user.
    final taskAssignments = await DaoWorkAssignmentTask().getByTask(task);
    if (taskAssignments.isEmpty) {
      await DaoTask().delete(task.id);
      return true;
    } else {
      final message = StringBuffer()
        ..writeln(
          'Deleting this Task will affect the following Work Assignments',
        );
      final assignedTo = <String>[];
      for (final assignment in taskAssignments) {
        final workAssignment = await DaoWorkAssignment().getById(
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
      var deleted = false;
      if (mounted) {
        await askUserToContinue(
          context: context,
          title: 'Task is assigned to Work Assignment',
          message: message.toString(),
          yesLabel: 'Continue?',
          noLabel: 'Cancel',
          onConfirmed: () async {
            await DaoTask().delete(task.id);
            deleted = true;
          },
        );
      }
      return deleted;
    }
  }

  Future<List<Task>> _fetchTasks(String? filter) async {
    final showInactive = June.getState(
      ShowInActiveTasksState.new,
    )._showInActiveTasks;
    final tasks = await DaoTask().getTasksByJob(widget.parent.parent!.id);

    final included = <Task>[];
    for (final task in tasks) {
      final status = task.status;
      final intActive = status.isInActive();
      if ((showInactive && intActive) || (!showInactive && !intActive)) {
        included.add(task);
      }
    }
    return included;
  }

  Widget _buildFullTasksDetails(Task task) =>
      ListTaskCard(job: widget.parent.parent!, task: task, summary: false);
}

class ShowInActiveTasksState extends JuneState {
  var _showInActiveTasks = false;

  void toggle() {
    _showInActiveTasks = !_showInActiveTasks;
    setState(); // Notify listeners to rebuild
  }
}
