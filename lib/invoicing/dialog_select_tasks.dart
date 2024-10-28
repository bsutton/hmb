import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../dao/dao_task.dart';
import '../entity/job.dart';
import '../widgets/async_state.dart';

enum Showing { showQuote, showInvoice }

/// show the user the set of tasks for the passed Job
/// and allow them to select which tasks they want to
/// work on.
class DialogTaskSelection extends StatefulWidget {
  const DialogTaskSelection(
      {required this.job, required this.showing, super.key});
  final Job job;
  final Showing showing;

  @override
  // ignore: library_private_types_in_public_api
  _DialogTaskSelectionState createState() => _DialogTaskSelectionState();

  /// Show the dialog
  static Future<InvoiceOptions?> showQuote({
    required BuildContext context,
    required Job job,
  }) async {
    final invoiceOptions = await showDialog<InvoiceOptions>(
      context: context,
      builder: (context) =>
          DialogTaskSelection(job: job, showing: Showing.showQuote),
    );

    return invoiceOptions;
  }

  /// Show the dialog
  static Future<InvoiceOptions?> showInvoice({
    required BuildContext context,
    required Job job,
  }) async {
    final invoiceOptions = await showDialog<InvoiceOptions>(
      context: context,
      builder: (context) =>
          DialogTaskSelection(job: job, showing: Showing.showInvoice),
    );

    return invoiceOptions;
  }
}

class InvoiceOptions {
  InvoiceOptions({required this.selectedTaskIds, required this.billBookingFee});
  List<int> selectedTaskIds = [];
  bool billBookingFee = true;
}

class _DialogTaskSelectionState
    extends AsyncState<DialogTaskSelection, List<TaskAccruedValue>> {
  // late List<TaskEstimates> _tasks;
  final Map<int, bool> _selectedTasks = {};
  bool _selectAll = true;
  bool billBookingFee = true;

  @override
  Future<List<TaskAccruedValue>> asyncInitState() async {
    // Load tasks and their costs via the DAO
    final tasksAccruedValue = await DaoTask().getTaskCostsByJob(
        jobId: widget.job.id,
        includeBilled: widget.showing == Showing.showQuote);

    /// Mark all tasks as selected.
    for (final accuredValue in tasksAccruedValue) {
      _selectedTasks[accuredValue.task.id] = true;
    }

    return tasksAccruedValue;
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
        content: FutureBuilderEx<List<TaskAccruedValue>>(
            future: initialised,
            builder: (context, taskEstimates) => SingleChildScrollView(
                  child: Column(
                    children: [
                      CheckboxListTile(
                          title: const Text('Bill booking Fee'),
                          value: billBookingFee,
                          onChanged: (value) => billBookingFee = value ?? true),
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
              Navigator.of(context).pop(InvoiceOptions(
                  selectedTaskIds: selectedTaskIds,
                  billBookingFee: billBookingFee));
            },
            child: const Text('OK'),
          ),
        ],
      );
}
