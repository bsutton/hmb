import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../dao/dao_task.dart';
import '../entity/job.dart';
import '../entity/task.dart';
import '../widgets/async_state.dart';

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

class _DialogTaskSelectionState
    extends AsyncState<DialogTaskSelection, List<TaskEstimates>> {
  // late List<TaskEstimates> _tasks;
  final Map<int, bool> _selectedTasks = {};
  bool _selectAll = true;

  @override
  Future<List<TaskEstimates>> asyncInitState() async {
    // Load tasks and their costs via the DAO
    final tasksEstimates = await DaoTask()
        .getTaskCostsByJob(widget.job.id, widget.job.hourlyRate!);

    /// Mark all tasks as selected.
    for (final estimate in tasksEstimates) {
      _selectedTasks[estimate.task.id] = true;
    }

    return tasksEstimates;
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
        content: FutureBuilderEx<List<TaskEstimates>>(
            future: initialised,
            builder: (context, taskEstimates) => SingleChildScrollView(
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('Select All'),
                        value: _selectAll,
                        onChanged: _toggleSelectAll,
                      ),
                      for (final taskCost in taskEstimates!)
                        CheckboxListTile(
                          title: Text(taskCost.task.name),
                          subtitle: Text('Total Cost: ${taskCost.cost}'),
                          value: _selectedTasks[taskCost.task.id] ?? false,
                          onChanged: (value) =>
                              _toggleIndividualTask(taskCost.task.id, value),
                        ),
                    ],
                  ),
                )),
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
