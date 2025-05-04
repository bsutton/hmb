import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../dao/dao_contact.dart';
import '../../dao/dao_task.dart';
import '../../entity/entity.g.dart';
import '../widgets/hmb_button.dart';

enum Showing { showQuote, showInvoice }

Future<InvoiceOptions?> showQuote({
  required BuildContext context,
  required Job job,
}) async {
  final estimates = await DaoTask().getEstimatesForJob(job.id);

  final contact =
      await DaoContact().getPrimaryForJob(job.id) ??
      (throw Exception('No primary contact found for job'));
  if (context.mounted) {
    final invoiceOptions = await showDialog<InvoiceOptions>(
      context: context,
      builder:
          (context) => DialogTaskSelection(
            job: job,
            contact: contact,
            taskSelectors:
                estimates
                    .map(
                      (estimate) => TaskSelector(
                        estimate.task,
                        estimate.task.name,
                        estimate.total,
                      ),
                    )
                    .toList(),
          ),
    );

    return invoiceOptions;
  }
  return null;
}

Future<InvoiceOptions?> showInvoice({
  required BuildContext context,
  required Job job,
}) async {
  final values = await DaoTask().getAccruedValueForJob(
    jobId: job.id,
    includedBilled: false,
  );

  final selectors = <TaskSelector>[];
  for (final value in values) {
    selectors.add(
      TaskSelector(value.task, value.task.name, await value.earned),
    );
  }

  final contact =
      await DaoContact().getPrimaryForJob(job.id) ??
      (throw Exception('No primary contact found for job'));
  if (context.mounted) {
    final invoiceOptions = await showDialog<InvoiceOptions>(
      context: context,
      builder:
          (context) => DialogTaskSelection(
            job: job,
            contact: contact,
            taskSelectors: selectors,
          ),
    );
    return invoiceOptions;
  }
  return null;
}

class DialogTaskSelection extends StatefulWidget {
  const DialogTaskSelection({
    required this.job,
    required this.taskSelectors,
    required this.contact,
    super.key,
  });

  final Job job;
  final List<TaskSelector> taskSelectors;
  final Contact contact;

  @override
  _DialogTaskSelectionState createState() => _DialogTaskSelectionState();
}

class TaskSelector {
  TaskSelector(this.task, this.description, this.value);
  final Task task;
  final String description;
  final Money value;
}

class InvoiceOptions {
  InvoiceOptions({
    required this.selectedTaskIds,
    required this.billBookingFee,
    required this.groupByTask,
    required this.contact,
  });

  List<int> selectedTaskIds = [];
  // ignore: omit_obvious_property_types
  bool billBookingFee = true;
  bool groupByTask;
  Contact contact;
}

class _DialogTaskSelectionState extends DeferredState<DialogTaskSelection> {
  final Map<int, bool> _selectedTasks = {};
  var _selectAll = true;
  late bool billBookingFee;
  late bool canBillBookingFee;
  var _groupByTask = false;

  List<Contact> _contacts = [];
  late Contact _selectedContact;

  @override
  Future<void> asyncInitState() async {
    billBookingFee =
        canBillBookingFee =
            widget.job.billingType == BillingType.timeAndMaterial &&
            !widget.job.bookingFeeInvoiced;

    for (final accuredValue in widget.taskSelectors) {
      _selectedTasks[accuredValue.task.id] = true;
    }

    _contacts = await DaoContact().getByCustomer(widget.job.customerId);
    _selectedContact = _contacts.firstWhere(
      (c) => c.id == widget.contact.id,
      orElse: () => _contacts.first,
    );
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
    title: Text('Select tasks to bill: ${widget.job.summary}'),
    content: DeferredBuilder(
      this,
      builder:
          (context) => SingleChildScrollView(
            child: Column(
              children: [
                if (_contacts.isNotEmpty)
                  DropdownButton<Contact>(
                    value: _selectedContact,
                    isExpanded: true,
                    onChanged: (value) {
                      setState(() {
                        _selectedContact = value!;
                      });
                    },
                    items:
                        _contacts
                            .map(
                              (contact) => DropdownMenuItem(
                                value: contact,
                                child: Text(contact.fullname),
                              ),
                            )
                            .toList(),
                  ),
                const SizedBox(height: 20),
                DropdownButton<bool>(
                  value: _groupByTask,
                  isExpanded: true,
                  onChanged: (value) {
                    setState(() {
                      _groupByTask = value ?? true;
                    });
                  },
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
                    },
                  ),
                if (_selectedTasks.isNotEmpty)
                  CheckboxListTile(
                    title: const Text('Select All'),
                    value: _selectAll,
                    onChanged: _toggleSelectAll,
                  ),
                for (final taskSelector in widget.taskSelectors)
                  CheckboxListTile(
                    title: Text(taskSelector.description),
                    subtitle: Text('Total Cost: ${taskSelector.value}'),
                    value: _selectedTasks[taskSelector.task.id] ?? false,
                    onChanged:
                        (value) =>
                            _toggleIndividualTask(taskSelector.task.id, value),
                  ),
              ],
            ),
          ),
    ),
    actions: [
      HMBButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      HMBButton(
        label: 'OK',
        onPressed: () {
          final selectedTaskIds =
              _selectedTasks.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList();
          Navigator.of(context).pop(
            InvoiceOptions(
              selectedTaskIds: selectedTaskIds,
              billBookingFee: billBookingFee,
              groupByTask: _groupByTask,
              contact: _selectedContact,
            ),
          );
        },
      ),
    ],
  );

  Future<Money> cost(TaskAccruedValue taskCost, Showing showing) {
    switch (showing) {
      case Showing.showQuote:
        return taskCost.quoted;
      case Showing.showInvoice:
        return taskCost.earned;
    }
  }
}
