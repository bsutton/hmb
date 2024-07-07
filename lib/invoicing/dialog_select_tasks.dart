import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../dao/dao_checklist_item.dart';
import '../dao/dao_task.dart';
import '../dao/dao_time_entry.dart';
import '../entity/job.dart';
import '../entity/task.dart';
import '../util/exceptions.dart';
import '../util/money_ex.dart';

/// show the user the set of tasks for the passed Job
/// and allow them to select which tasks they want to
/// work on.
class DialogTaskSelection extends StatefulWidget {
  const DialogTaskSelection({required this.job, super.key});
  final Job job;

  @override
  // ignore: library_private_types_in_public_api
  _DialogTaskSelectionState createState() => _DialogTaskSelectionState();

  /// Show the dialog
  static Future<List<int>> show(BuildContext context, Job job) async {

    final selectedTaskIds = await showDialog<List<int>>(
      context: context,
      builder: (context) => DialogTaskSelection(job: job),
    );

    return selectedTaskIds ?? [];
  }
}

class _DialogTaskSelectionState extends State<DialogTaskSelection> {
  late Future<List<Task>> _tasks;
  final Map<int, bool> _selectedTasks = {};

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _tasks = _loadTasks();
  }

  Future<List<Task>> _loadTasks() async {
    final tasks = await DaoTask().getTasksByJob(widget.job);
    final billableTasks = <Task>[];
    for (final task in tasks) {
      if ((await _calculateTaskCost(task)) > MoneyEx.zero) {
        _selectedTasks[task.id] = true;
        billableTasks.add(task);
      }
    }
    return billableTasks;
  }

  Future<Money> _calculateTaskCost(Task task) async {
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

    return totalCost;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Select tasks to bill for Job: ${widget.job.summary}'),
        content: FutureBuilderEx<List<Task>>(
          future: _tasks,
          builder: (context, tasks) => Column(
            mainAxisSize: MainAxisSize.min,
            children: tasks!
                .map((task) => FutureBuilderEx<Money>(
                      // ignore: discarded_futures
                      future: _calculateTaskCost(task),
                      waitingBuilder: (_) => ListTile(
                        title: Text(task.name),
                        subtitle: const Text('Calculating cost...'),
                        trailing: const CircularProgressIndicator(),
                      ),
                      builder: (context, cost) => CheckboxListTile(
                        title: Text(task.name),
                        subtitle: Text('Total Cost: $cost'),
                        value: _selectedTasks[task.id] ?? false,
                        onChanged: (value) {
                          setState(() {
                            _selectedTasks[task.id] = value!;
                          });
                        },
                      ),
                    ))
                .toList(),
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
