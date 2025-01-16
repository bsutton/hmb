import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../dao/dao_task.dart';
import '../../entity/job.dart';
import '../../entity/task.dart';
import '../widgets/async_state.dart';
import '../widgets/hmb_button.dart';

enum Showing { showQuote, showInvoice }

/// Show the dialog
Future<InvoiceOptions?> showQuote({
  required BuildContext context,
  required Job job,
}) async {
  final estimates = await DaoTask().getEstimatesForJob(job.id);

  if (context.mounted) {
    final invoiceOptions = await showDialog<InvoiceOptions>(
        context: context,
        builder: (context) => DialogTaskSelection(
            job: job,
            taskSelectors: estimates
                .map((estimate) => TaskSelector(
                    estimate.task, estimate.task.name, estimate.total))
                .toList()));

    return invoiceOptions;
  }
  return null;
}

/// Show the dialog
Future<InvoiceOptions?> showInvoice({
  required BuildContext context,
  required Job job,
}) async {
  final values = await DaoTask()
      .getAccruedValueForJob(jobId: job.id, includedBilled: false);

  final selectors = <TaskSelector>[];
  for (final value in values) {
    selectors
        .add(TaskSelector(value.task, value.task.name, await value.earned));
  }

  if (context.mounted) {
    final invoiceOptions = await showDialog<InvoiceOptions>(
        context: context,
        builder: (context) =>
            DialogTaskSelection(job: job, taskSelectors: selectors));
    return invoiceOptions;
  }
  return null;
}

/// show the user the set of tasks for the passed Job
/// and allow them to select which tasks they want to
/// work on.
class DialogTaskSelection extends StatefulWidget {
  const DialogTaskSelection(
      {required this.job, required this.taskSelectors, super.key});
  final Job job;
  final List<TaskSelector> taskSelectors;

  @override
  // ignore: library_private_types_in_public_api
  _DialogTaskSelectionState createState() => _DialogTaskSelectionState();
}

class TaskSelector {
  TaskSelector(this.task, this.description, this.value);
  final Task task;
  final String description;
  final Money value;
}

class InvoiceOptions {
  InvoiceOptions(
      {required this.selectedTaskIds,
      required this.billBookingFee,
      required this.groupByTask});
  List<int> selectedTaskIds = [];
  bool billBookingFee = true;
  bool groupByTask;
}

class _DialogTaskSelectionState
    extends AsyncState<DialogTaskSelection> {
  // late List<TaskEstimates> _tasks;
  final Map<int, bool> _selectedTasks = {};
  bool _selectAll = true;
  late bool billBookingFee;
  late bool canBillBookingFee;
  bool groupByTask = false;

  @override
  Future<void> asyncInitState() async {
    billBookingFee = canBillBookingFee =
        widget.job.billingType == BillingType.timeAndMaterial &&
            !widget.job.bookingFeeInvoiced;

    /// Mark all tasks as selected.
    for (final accuredValue in widget.taskSelectors) {
      _selectedTasks[accuredValue.task.id] = true;
    }

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
        content: FutureBuilderEx<void>(
            future: initialised,
            builder: (context, _) => SingleChildScrollView(
                  child: Column(
                    children: [
                      DropdownButton<bool>(
                        value: groupByTask,
                        items: const [
                          DropdownMenuItem(
                            value: true,
                            child: Text('Group by Task/Date'),
                          ),
                          DropdownMenuItem(
                            value: false,
                            child: Text('Group by Date/Task'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            groupByTask = value ?? true;
                          });
                        },
                        isExpanded: true,
                      ),
                      const SizedBox(height: 20),
                      if (canBillBookingFee)
                        CheckboxListTile(
                            title: const Text('Bill booking Fee'),
                            value: billBookingFee,
                            onChanged: (value) {
                              setState(() {
                                billBookingFee = value ?? true;
                              });
                            }),
                      if (_selectedTasks.isNotEmpty)
                        CheckboxListTile(
                          title: const Text('Select All'),
                          value: _selectAll,
                          onChanged: _toggleSelectAll,
                        ),
                      for (final taskSelector in widget.taskSelectors)
                        CheckboxListTile(
                          title: Text(taskSelector.description),
                          subtitle:
                              Text('''Total Cost: ${taskSelector.value}'''),
                          value: _selectedTasks[taskSelector.task.id] ?? false,
                          onChanged: (value) => _toggleIndividualTask(
                              taskSelector.task.id, value),
                        ),
                    ],
                  ),
                )),
        actions: [
          HMBButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          HMBButton(
            label: 'OK',
            onPressed: () {
              final selectedTaskIds = _selectedTasks.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList();
              Navigator.of(context).pop(InvoiceOptions(
                  selectedTaskIds: selectedTaskIds,
                  billBookingFee: billBookingFee,
                  groupByTask: groupByTask));
            },
          ),
        ],
      );

  Future<Money> cost(TaskAccruedValue taskCost, Showing showing) async {
    switch (showing) {
      case Showing.showQuote:
        return taskCost.quoted;
      case Showing.showInvoice:
        return taskCost.earned;
    }
  }
}
