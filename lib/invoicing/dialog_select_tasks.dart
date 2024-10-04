import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../dao/dao_task.dart';
import '../entity/job.dart';
import '../util/money_ex.dart';
import '../widgets/async_state.dart';

enum _Showing { showQuote, showInvoice }

/// show the user the set of tasks for the passed Job
/// and allow them to select which tasks they want to
/// work on.
class DialogTaskSelection extends StatefulWidget {
  const DialogTaskSelection(
      {required this.job, required this.showing, super.key});
  final Job job;
  final _Showing showing;

  @override
  // ignore: library_private_types_in_public_api
  _DialogTaskSelectionState createState() => _DialogTaskSelectionState();

  /// Show the dialog
  static Future<List<int>> showQuote({
    required BuildContext context,
    required Job job,
  }) async {
    final selectedTaskIds = await showDialog<List<int>>(
      context: context,
      builder: (context) =>
          DialogTaskSelection(job: job, showing: _Showing.showQuote),
    );

    return selectedTaskIds ?? [];
  }

  /// Show the dialog
  static Future<List<int>> showInvoice({
    required BuildContext context,
    required Job job,
  }) async {
    final selectedTaskIds = await showDialog<List<int>>(
      context: context,
      builder: (context) =>
          DialogTaskSelection(job: job, showing: _Showing.showInvoice),
    );

    return selectedTaskIds ?? [];
  }
}

class _DialogTaskSelectionState
    extends AsyncState<DialogTaskSelection, List<TaskAccuredValue>> {
  // late List<TaskEstimates> _tasks;
  final Map<int, bool> _selectedTasks = {};
  bool _selectAll = true;

  @override
  Future<List<TaskAccuredValue>> asyncInitState() async {
    // Load tasks and their costs via the DAO
    final tasksAccruedValue = await DaoTask().getTaskCostsByJob(
        jobId: widget.job.id,
        includeBilled: widget.showing == _Showing.showQuote);

    /// Mark all tasks as selected.
    for (final accuredValue in tasksAccruedValue) {
      if ((await accuredValue.earned) == MoneyEx.zero) {
        continue;
      }
      _selectedTasks[accuredValue.task.id] = true;
    }

    return tasksAccruedValue
        .where((accrued)  => (await accrued.earned) != MoneyEx.zero)
        .toList();
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
        content: FutureBuilderEx<List<TaskAccuredValue>>(
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
                          subtitle: Text(
                              '''Total Cost: ${taskCost.taskEstimatedValue.estimatedMaterialsCharge}'''),
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
