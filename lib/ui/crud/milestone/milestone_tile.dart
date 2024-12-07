import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../../dao/dao_invoice.dart';
import '../../../entity/invoice.dart';
import '../../../entity/milestone.dart';
import '../../../util/money_ex.dart';
import '../../invoicing/edit_invoice_screen.dart'; // Ensure InvoiceEditScreen is imported
import '../../invoicing/invoice_details.dart';
import '../../widgets/hmb_toast.dart';

class MilestoneTile extends StatefulWidget {
  const MilestoneTile({
    required this.milestone,
    required this.quoteTotal,
    required this.onDelete,
    required this.onSave,
    required this.onInvoice,
    required this.onEditingStatusChanged,
    required this.isOtherTileEditing,
    super.key,
  });

  final Milestone milestone;
  final Money quoteTotal;
  final ValueChanged<Milestone> onDelete;
  final ValueChanged<Milestone> onSave;
  final Future<void> Function(Milestone milestone) onInvoice;
  // ignore: avoid_positional_boolean_parameters
  final void Function(Milestone, bool) onEditingStatusChanged;
  final bool isOtherTileEditing;

  @override
  _MilestoneTileState createState() => _MilestoneTileState();
}

class _MilestoneTileState extends State<MilestoneTile> {
  late TextEditingController descriptionController;
  late TextEditingController percentageController;
  late TextEditingController amountController;

  bool isEditable = true;
  bool isInEditMode = false; // Track if this tile is currently being edited
  bool changing = false;

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
  }

  @override
  void dispose() {
    descriptionController.dispose();
    percentageController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    if (!isInEditMode) {
      setState(() {
        isInEditMode = true;
      });
      widget.onEditingStatusChanged(widget.milestone, true);
    }
  }

  void _onDescriptionChanged() {
    _enterEditMode();
  }

  void _onPercentageChanged() {
    _enterEditMode();

    if (!changing) {
      changing = true;
      final percentage = Percentage.tryParse(percentageController.text);

      /// Calc the amount based on the percentage just entered by the user.
      final amount = widget.quoteTotal
          .multipliedByPercentage(percentage ?? Percentage.zero);
      amountController.text = amount.toString();
      changing = false;
    }
  }

  void _onAmountChanged() {
    _enterEditMode();

    if (!changing) {
      changing = true;
      final amount = MoneyEx.tryParse(amountController.text);

      // Update the percentage based on the amount the user has just entered.
      final percentage = amount.percentageOf(widget.quoteTotal);
      percentageController.text = percentage.toString();
      changing = false;
    }
  }

  void _onDeletePressed() {
    // Deletion doesn't require edit mode changes.
    widget.onDelete(widget.milestone);
  }

  Future<void> _onInvoicePressed() async {
    if (widget.milestone.paymentAmount <= MoneyEx.zero) {
      HMBToast.error(
          'You cannot invoice a milestone with a zero or negative amount.');
      return;
    }

    await widget.onInvoice(widget.milestone);
    HMBToast.info('Invoice created: #${widget.milestone.invoiceId}');
    setState(() {
      isEditable = false;
    });
  }

  void _onSavePressed() {
    // User finished editing, apply changes

    widget.milestone.milestoneDescription = descriptionController.text;

    final amount = Money.tryParse(amountController.text, isoCode: 'AUD');
    if (amount == null) {
      HMBToast.error('The amount ${amountController.text} is invalid');
      return;
    }
    amountController.text = amount.toString();
    widget.milestone.paymentAmount = amount;

    final percentage = Percentage.tryParse(percentageController.text);
    if (percentage == null) {
      HMBToast.error('The percentage ${percentageController.text} is invalid');
      return;
    }

    percentageController.text = percentage.toString();
    widget.milestone.paymentPercentage = percentage;

    widget.milestone.edited = true;

    setState(() {
      isInEditMode = false;
    });
    widget.onEditingStatusChanged(widget.milestone, false);
    widget.onSave(widget.milestone);
  }

  @override
  Widget build(BuildContext context) {
    final shouldDisable = widget.isOtherTileEditing;
    final tileOpacity = shouldDisable ? 0.5 : 1.0;

    return Opacity(
      opacity: tileOpacity,
      child: Card(
        key: widget.key,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          title: Text('Milestone ${widget.milestone.milestoneNumber}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.milestone.invoiceId != null)
                FutureBuilderEx<Invoice?>(
                    // ignore: discarded_futures
                    future: DaoInvoice().getById(widget.milestone.invoiceId),
                    builder: (context, invoice) {
                      final inv = invoice;
                      if (inv == null) {
                        return const Text('Not Invoiced');
                      } else {
                        // Make invoice number clickable to open InvoiceEditScreen
                        return InkWell(
                          onTap: () async {
                            final invoiceDetails =
                                await InvoiceDetails.load(inv.id);
                            // Navigate to InvoiceEditScreen with this invoice
                            if (context.mounted) {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) => InvoiceEditScreen(
                                      invoiceDetails: invoiceDetails),
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Invoice: ${inv.bestNumber}',
                            style: const TextStyle(
                                color: Colors.green,
                                decoration: TextDecoration.underline),
                          ),
                        );
                      }
                    }),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                enabled: isEditable && !shouldDisable,
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
                      enabled: isEditable && !shouldDisable,
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
                      enabled: isEditable && !shouldDisable,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                      ],
                      onChanged: (_) => _onAmountChanged(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Wrap(
            spacing: 8,
            children: [
              if (isInEditMode)
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.green),
                  onPressed: shouldDisable ? null : _onSavePressed,
                  tooltip: 'Save changes',
                )
              else ...[
                if (isEditable)
                  IconButton(
                    icon: const Icon(Icons.receipt, color: Colors.blue),
                    onPressed: shouldDisable ? null : _onInvoicePressed,
                    tooltip: 'Invoice this Milestone',
                  ),
                if (isEditable)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: shouldDisable ? null : _onDeletePressed,
                    tooltip: 'Delete this Milestone',
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
