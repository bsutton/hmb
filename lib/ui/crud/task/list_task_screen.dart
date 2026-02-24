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
import 'package:strings/strings.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';
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
            onDelete: onDelete,
            canEdit: (_) => !widget.parent.parent!.isStock,
            canDelete: (_) => !widget.parent.parent!.isStock,

            listCard: _buildFullTasksDetails,
            // : _buildTaskSummary(task),
          ),
        ),
      ],
    );
  }

  Future<bool> onDelete(Task task) async {
    if (widget.parent.parent!.isStock) {
      HMBToast.error('The Stock task cannot be deleted.');
      return false;
    }

    // assigned tasks cannot be deleted.
    final taskAssignments = await DaoWorkAssignmentTask().getByTask(task);
    if (taskAssignments.isNotEmpty) {
      HMBToast.error(
        'Task cannot be deleted while it is assigned to a Work Assignment.',
      );
      return false;
    }

    await DaoTask().delete(task.id);
    return true;
  }

  Future<List<Task>> _fetchTasks(String? filter) async {
    final showInactive = June.getState(
      ShowInActiveTasksState.new,
    )._showInActiveTasks;
    final search = filter?.trim().toLowerCase();
    final tasks = await DaoTask().getTasksByJob(widget.parent.parent!.id);

    final included = <Task>[];
    for (final task in tasks) {
      final status = task.status;
      final intActive = status.isInActive();
      final matchesSearch =
          Strings.isBlank(search) ||
          task.name.toLowerCase().contains(search!) ||
          task.description.toLowerCase().contains(search) ||
          task.assumption.toLowerCase().contains(search);
      if ((showInactive && intActive) || (!showInactive && !intActive)) {
        if (matchesSearch) {
          included.add(task);
        }
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
