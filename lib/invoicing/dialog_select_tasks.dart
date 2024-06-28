import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../dao/dao_checklist_item.dart';
import '../dao/dao_task.dart';
import '../dao/dao_time_entry.dart';
import '../entity/job.dart';
import '../entity/task.dart';

/// show the user the set of tasks for the passed Job
/// and allow them to select which tasks they want to
/// work on.
class DialogTaskSelection extends StatefulWidget {
  const DialogTaskSelection({required this.job, super.key});
  final Job job;

  @override
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
    _tasks = _loadTasks();
  }

  Future<List<Task>> _loadTasks() async {
    final tasks = await DaoTask().getTasksByJob(widget.job);
    for (final task in tasks) {
      _selectedTasks[task.id] = true;
    }
    return tasks;
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
        title: Text('Select Tasks to Bill for Job: ${widget.job.summary}'),
        content: FutureBuilder<List<Task>>(
          future: _tasks,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final tasks = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: tasks
                  .map((task) => FutureBuilder<Money>(
                        // ignore: discarded_futures
                        future: _calculateTaskCost(task),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return ListTile(
                              title: Text(task.name),
                              subtitle: const Text('Calculating cost...'),
                              trailing: const CircularProgressIndicator(),
                            );
                          }

                          final cost = snapshot.data!;
                          return CheckboxListTile(
                            title: Text(task.name),
                            subtitle: Text('Total Cost: $cost'),
                            value: _selectedTasks[task.id],
                            onChanged: (value) {
                              setState(() {
                                _selectedTasks[task.id] = value!;
                              });
                            },
                          );
                        },
                      ))
                  .toList(),
            );
          },
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
