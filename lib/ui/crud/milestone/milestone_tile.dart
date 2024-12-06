import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../../dao/dao_invoice.dart';
import '../../../entity/milestone.dart';
import '../../../util/format.dart';
import '../../../util/local_date.dart';
import '../../../util/money_ex.dart';

class MilestoneTile extends StatefulWidget {
  const MilestoneTile({
    required this.milestone,
    required this.quoteTotal,
    required this.onChanged,
    required this.onDelete,
    required this.onInvoice,
    super.key,
  });

  final Milestone milestone;
  final Money quoteTotal;
  final ValueChanged<Milestone> onChanged;
  final ValueChanged<Milestone> onDelete;
  final ValueChanged<Milestone> onInvoice;

  @override
  _MilestoneTileState createState() => _MilestoneTileState();
}

class _MilestoneTileState extends State<MilestoneTile> {
  late TextEditingController descriptionController;
  late TextEditingController percentageController;
  late TextEditingController amountController;
  late TextEditingController dueDateController;

  bool isEditable = true;

  @override
  void initState() {
    super.initState();
    isEditable = widget.milestone.invoiceId == null;

    descriptionController =
        TextEditingController(text: widget.milestone.milestoneDescription);
    percentageController = TextEditingController(
      text: widget.milestone.paymentPercentage.toString(),
    );
    amountController = TextEditingController(
      text: widget.milestone.paymentAmount.toString(),
    );
    dueDateController = TextEditingController(
      text: widget.milestone.dueDate == null
          ? ''
          : formatLocalDate(widget.milestone.dueDate!),
    );
  }

  @override
  void dispose() {
    descriptionController.dispose();
    percentageController.dispose();
    amountController.dispose();
    dueDateController.dispose();
    super.dispose();
  }

  void _onDescriptionChanged() {
    widget.milestone.milestoneDescription = descriptionController.text;
    widget.onChanged(widget.milestone);
  }

  void _onPercentageChanged() {
    final percentage = Percentage.tryParse(percentageController.text);
    widget.milestone.paymentPercentage = percentage;
    widget.milestone.paymentAmount =
        widget.quoteTotal.multipliedByPercentage(percentage);
    amountController.text = widget.milestone.paymentAmount.toString();
    widget.onChanged(widget.milestone);
  }

  void _onAmountChanged() {
    final amount = MoneyEx.tryParse(amountController.text);
    widget.milestone.paymentPercentage = amount.percentageOf(widget.quoteTotal);
    percentageController.text = widget.milestone.paymentPercentage.toString();
    widget.onChanged(widget.milestone);
  }

  Future<void> _onDueDateChanged() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.milestone.dueDate?.toDateTime() ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      widget.milestone.dueDate = LocalDate.fromDateTime(pickedDate);
      dueDateController.text = widget.milestone.dueDate.toString();
      widget.onChanged(widget.milestone);
    }
  }

  void _onDeletePressed() {
    widget.onDelete(widget.milestone);
  }

  Future<void> _onInvoicePressed() async {
    // Assume the onInvoice callback handles creating an invoice
    // for this milestone
    widget.onInvoice(widget.milestone);

    // Mark the milestone as invoiced locally
    setState(() {
      isEditable = false;
    });
    widget.onChanged(widget.milestone);
  }

  @override
  Widget build(BuildContext context) => Card(
        key: widget.key,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          title: Text('Milestone ${widget.milestone.milestoneNumber}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.milestone.invoiceId != null)
                FutureBuilderEx(
                    // ignore: discarded_futures
                    future: DaoInvoice().getById(widget.milestone.invoiceId),
                    builder: (contex, invoice) => Text(
                          'Invoiced: ${invoice!.bestNumber}',
                          style: const TextStyle(color: Colors.green),
                        )),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                enabled: isEditable,
                onChanged: (_) => _onDescriptionChanged(),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: percentageController,
                      decoration:
                          const InputDecoration(labelText: 'Percentage'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      enabled: isEditable,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                      ],
                      onChanged: (_) => _onPercentageChanged(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      enabled: isEditable,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                      ],
                      onChanged: (_) => _onAmountChanged(),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: dueDateController,
                decoration: const InputDecoration(labelText: 'Due Date'),
                readOnly: true,
                onTap: _onDueDateChanged,
              ),
            ],
          ),
          trailing: Wrap(
            spacing: 8,
            children: [
              if (isEditable)
                IconButton(
                  icon: const Icon(Icons.receipt, color: Colors.blue),
                  onPressed: _onInvoicePressed,
                  tooltip: 'Invoice this Milestone',
                ),
              if (isEditable)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _onDeletePressed,
                  tooltip: 'Delete this Milestone',
                ),
            ],
          ),
        ),
      );
}
