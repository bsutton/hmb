import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../dao/dao_checklist_item.dart';
import '../dao/dao_task.dart';
import '../dao/dao_time_entry.dart';
import '../entity/job.dart';
import '../entity/task.dart';
import '../util/money_ex.dart';

/// show the user the set of tasks for the passed Job
/// and allow them to select which tasks they want to
/// work on.
class DialogTaskSelection extends StatefulWidget {
  const DialogTaskSelection(
      {required this.job, required this.includeEstimatedTasks, super.key});
  final Job job;
  final bool includeEstimatedTasks;

  @override
  // ignore: library_private_types_in_public_api
  _DialogTaskSelectionState createState() => _DialogTaskSelectionState();

  /// Show the dialog
  static Future<List<int>> show(
      {required BuildContext context,
      required Job job,
      required bool includeEstimatedTasks}) async {
    final selectedTaskIds = await showDialog<List<int>>(
      context: context,
      builder: (context) => DialogTaskSelection(
          job: job, includeEstimatedTasks: includeEstimatedTasks),
    );

    return selectedTaskIds ?? [];
  }
}

class _DialogTaskSelectionState extends State<DialogTaskSelection> {
  late Future<List<TaskCost>> _tasks;
  final Map<int, bool> _selectedTasks = {};
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _tasks = _loadTasks();
  }

  Future<List<TaskCost>> _loadTasks() async {
    final tasks = await DaoTask().getTasksByJob(widget.job.id);
    final billableTasks = <TaskCost>[];

    for (final task in tasks) {
      final taskCost = await _calculateTaskCost(task);
      if (taskCost.cost > MoneyEx.zero) {
        _selectedTasks[task.id] = true;
        billableTasks.add(taskCost);
      }
      if (widget.includeEstimatedTasks) {
        if (task.estimatedCost != null || task.effortInHours != null) {
          billableTasks.add(taskCost);
          _selectedTasks[task.id] = true;
        }
      }
    }
    return billableTasks;
  }

  Future<TaskCost> _calculateTaskCost(Task task) async {
    var totalCost = Money.fromInt(0, isoCode: 'AUD');
    final timeEntries = await DaoTimeEntry().getByTask(task.id);
    final checkListItems = await DaoCheckListItem().getByTask(task);

    for (final entry in timeEntries.where((entry) => !entry.billed)) {
      final duration = entry.duration.inMinutes / 60;
      totalCost +=
          widget.job.hourlyRate!.multiplyByFixed(Fixed.fromNum(duration));
    }

    for (final item in checkListItems.where((item) => !item.billed)) {
      totalCost += item.unitCost.multiplyByFixed(item.quantity);
    }

    return TaskCost(task, totalCost);
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      for (final key in _selectedTasks.keys) {
        _selectedTasks[key] = _selectAll;
      }
    });
  }

  void _toggleIndividualTask(int taskId, bool? value) {
    setState(() {
      _selectedTasks[taskId] = value ?? false;
      if (_selectedTasks.values.every((isSelected) => isSelected)) {
        _selectAll = true;
      } else if (_selectedTasks.values.every((isSelected) => !isSelected)) {
        _selectAll = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Select tasks to bill for Job: ${widget.job.summary}'),
        content: FutureBuilderEx<List<TaskCost>>(
          future: _tasks,
          builder: (context, tasks) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Select All'),
                value: _selectAll,
                onChanged: _toggleSelectAll,
              ),
              for (final taskCost in tasks!)
                CheckboxListTile(
                  title: Text(taskCost.task.name),
                  subtitle: Text('Total Cost: ${taskCost.cost}'),
                  value: _selectedTasks[taskCost.task.id] ?? false,
                  onChanged: (value) =>
                      _toggleIndividualTask(taskCost.task.id, value),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final selectedTaskIds = _selectedTasks.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList();
              Navigator.of(context).pop(selectedTaskIds);
            },
            child: const Text('OK'),
          ),
        ],
      );
}

class TaskCost {
  TaskCost(this.task, this.cost);
  Task task;
  Money cost;
}
