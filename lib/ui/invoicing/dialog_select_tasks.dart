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

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_select_contact.dart';
import '../widgets/widgets.g.dart';
import 'invoice_options.dart';

enum Showing { showQuote, showInvoice }

/// Tasks for Quote
Future<InvoiceOptions?> selectTaskToQuote({
  required BuildContext context,
  required Job job,
  required String title,
}) async {
  final tasks = await DaoTask().getTasksByJob(job.id);
  final estimates = await DaoTask().getEstimatesForJob(job);
  final quoteEligible = estimates
      .where(
        (estimate) =>
            estimate.task.effectiveBillingType(job.billingType) ==
            BillingType.fixedPrice,
      )
      .toList();

  if (quoteEligible.isEmpty) {
    if (tasks.isEmpty) {
      HMBToast.error(
        'This job has no tasks. Add at least one task before creating a quote.',
        acknowledgmentRequired: true,
      );
    } else {
      HMBToast.error(
        'No tasks are eligible for a quote. Tasks must be Fixed Price, active, '
        'and have a non-zero estimate.',
        acknowledgmentRequired: true,
      );
    }
    return null;
  }

  final contact = await DaoContact().getBillingContactByJob(job);

  if (contact == null) {
    HMBToast.error(
      'You must select a Contact on the Job, before you can create a quote',
    );
    return null;
  }
  if (context.mounted) {
    final invoiceOptions = await showDialog<InvoiceOptions>(
      context: context,
      builder: (context) => DialogTaskSelection(
        job: job,
        contact: contact,
        title: title,
        forQuote: true,
        taskSelectors: quoteEligible
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

/// Tasks for Invoice
Future<InvoiceOptions?> selectTasksToInvoice({
  required BuildContext context,
  required Job job,
  required String title,
}) async {
  final values = await DaoTask().getAccruedValueForJob(
    job: job,
    includedBilled: false,
  );

  final selectors = <TaskSelector>[];
  for (final value in values) {
    selectors.add(
      TaskSelector(value.task, value.task.name, await value.earned),
    );
  }

  final contact =
      await DaoContact().getBillingContactByJob(job) ??
      (throw Exception('No Billing contact found for job'));
  if (context.mounted) {
    final invoiceOptions = await showDialog<InvoiceOptions>(
      context: context,
      builder: (context) => DialogTaskSelection(
        job: job,
        contact: contact,
        taskSelectors: selectors,
        title: title,
        forQuote: false,
      ),
    );
    return invoiceOptions;
  }
  return null;
}

class DialogTaskSelection extends StatefulWidget {
  final String title;
  final Job job;
  final List<TaskSelector> taskSelectors;
  final Contact contact;
  final bool forQuote;

  const DialogTaskSelection({
    required this.job,
    required this.taskSelectors,
    required this.contact,
    required this.title,
    required this.forQuote,
    super.key,
  });

  @override
  _DialogTaskSelectionState createState() => _DialogTaskSelectionState();
}

class _DialogTaskSelectionState extends DeferredState<DialogTaskSelection> {
  final Map<int, bool> _selectedTasks = {};
  final Map<int, BillingType> _taskBillingTypes = {};
  final Map<int, TextEditingController> _taskMarginControllers = {};
  var _selectAll = true;
  late bool billBookingFee;
  late bool canBillBookingFee;
  var _groupByTask = false;
  late final TextEditingController _quoteMarginController;

  late Customer _customer;
  late Contact _selectedContact;
  List<Contact> _contacts = [];

  @override
  Future<void> asyncInitState() async {
    _groupByTask = true;

    billBookingFee = canBillBookingFee =
        widget.job.billingType == BillingType.timeAndMaterial &&
        !widget.job.bookingFeeInvoiced;

    for (final accuredValue in widget.taskSelectors) {
      _selectedTasks[accuredValue.task.id] = true;
      _taskBillingTypes[accuredValue.task.id] = accuredValue.task
          .effectiveBillingType(widget.job.billingType);
      _taskMarginControllers[accuredValue.task.id] = TextEditingController(
        text: '0',
      );
    }
    _quoteMarginController = TextEditingController(text: '0');

    _customer = (await DaoCustomer().getById(widget.job.customerId))!;
    _contacts = await DaoContact().getByCustomer(widget.job.customerId);
    _selectedContact = widget.contact;
  }

  @override
  void dispose() {
    _quoteMarginController.dispose();
    for (final controller in _taskMarginControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasSelectedTimeAndMaterialsTasks => _selectedTasks.entries.any(
    (entry) =>
        entry.value &&
        _taskBillingTypes[entry.key] == BillingType.timeAndMaterial,
  );

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
    title: Text('${widget.title}: ${widget.job.summary}'),
    content: DeferredBuilder(
      this,
      builder: (context) => SingleChildScrollView(
        child: HMBColumn(
          children: [
            if (_contacts.isNotEmpty)
              HMBSelectContact(
                title: 'Billing Contact',

                initialContact: _selectedContact.id,
                customer: _customer,
                onSelected: (value) {
                  setState(() {
                    _selectedContact = value!;
                  });
                },
              ),
            if (_hasSelectedTimeAndMaterialsTasks)
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
                    child: Text('Group T&M labour by task'),
                  ),
                  DropdownMenuItem(
                    value: false,
                    child: Text('Group T&M labour by day'),
                  ),
                ],
              ),
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
            if (widget.forQuote)
              HMBTextField(
                controller: _quoteMarginController,
                labelText: 'Total Quote Margin (%)',
                keyboardType: TextInputType.number,
              ),
            for (final taskSelector in widget.taskSelectors)
              HMBColumn(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    title: Text(taskSelector.description),
                    subtitle: Text('Total Cost: ${taskSelector.value}'),
                    value: _selectedTasks[taskSelector.task.id] ?? false,
                    onChanged: (value) =>
                        _toggleIndividualTask(taskSelector.task.id, value),
                  ),
                  if (widget.forQuote &&
                      (_selectedTasks[taskSelector.task.id] ?? false))
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16),
                      child: HMBTextField(
                        controller:
                            _taskMarginControllers[taskSelector.task.id]!,
                        labelText:
                            'Task Margin (%) for ${taskSelector.description}',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    ),
    actions: [
      HMBButton(
        label: 'Cancel',
        hint: "Don't select any the task",
        onPressed: () => Navigator.of(context).pop(),
      ),
      HMBButton(
        label: 'OK',
        hint: 'Continue with the selected the tasks',
        onPressed: () {
          final selectedTaskIds = _selectedTasks.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList();
          final taskMargins = <int, Percentage>{};
          for (final taskId in selectedTaskIds) {
            final marginText = _taskMarginControllers[taskId]?.text ?? '0';
            taskMargins[taskId] =
                Percentage.tryParse(marginText, decimalDigits: 3) ??
                Percentage.zero;
          }
          Navigator.of(context).pop(
            InvoiceOptions(
              selectedTaskIds: selectedTaskIds,
              billBookingFee: billBookingFee,
              groupByTask: !_hasSelectedTimeAndMaterialsTasks || _groupByTask,
              contact: _selectedContact,
              quoteMargin:
                  Percentage.tryParse(
                    _quoteMarginController.text,
                    decimalDigits: 3,
                  ) ??
                  Percentage.zero,
              taskMargins: taskMargins,
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

class TaskSelector {
  final Task task;
  final String description;
  final Money value;

  TaskSelector(this.task, this.description, this.value);
}
