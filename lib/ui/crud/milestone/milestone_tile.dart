/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// ignore_for_file: discarded_futures

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../../dao/dao_invoice.dart';
import '../../../entity/invoice.dart';
import '../../../entity/milestone.dart';
import '../../../util/money_ex.dart';
import '../../invoicing/edit_invoice_screen.dart';
import '../../invoicing/invoice_details.dart';
import '../../widgets/hmb_add_button.dart';
import '../../widgets/hmb_icon_button.dart';
import '../../widgets/hmb_link_internal.dart';
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
  final void Function({required Milestone milestone, required bool isEditing})
  onEditingStatusChanged;
  final bool isOtherTileEditing;

  @override
  _MilestoneTileState createState() => _MilestoneTileState();
}

class _MilestoneTileState extends State<MilestoneTile> {
  late TextEditingController descriptionController;
  late TextEditingController percentageController;
  late TextEditingController amountController;

  var _isEditable = true;
  var _isInEditMode = false;
  var _changing = false;

  @override
  void initState() {
    super.initState();
    _isEditable = widget.milestone.invoiceId == null;
    descriptionController = TextEditingController(
      text: widget.milestone.milestoneDescription,
    );
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
    if (!_isInEditMode) {
      setState(() => _isInEditMode = true);
      widget.onEditingStatusChanged(
        milestone: widget.milestone,
        isEditing: true,
      );
    }
  }

  void _onDescriptionChanged() => _enterEditMode();

  void _onPercentageChanged() {
    _enterEditMode();
    if (!_changing) {
      _changing = true;
      final percentage =
          Percentage.tryParse(percentageController.text) ?? Percentage.zero;

      /// Calc the amount based on the percentage just entered by the user.
      final amount = widget.quoteTotal.multipliedByPercentage(percentage);
      amountController.text = amount.toString();
      _changing = false;
    }
  }

  void _onAmountChanged() {
    _enterEditMode();
    if (!_changing) {
      _changing = true;
      final amount = MoneyEx.tryParse(amountController.text);
      // Update the percentage based on the amount the user has just entered.
      final percentage = amount.percentageOf(widget.quoteTotal);
      percentageController.text = percentage.toString();
      _changing = false;
    }
  }

  void _onDeletePressed() => widget.onDelete(widget.milestone);

  Future<void> _onInvoicePressed() async {
    // New: ensure description exists
    final desc = descriptionController.text.trim();
    if (desc.isEmpty) {
      HMBToast.error('Please enter a description before invoicing.');
      return;
    }
    if (widget.milestone.paymentAmount <= MoneyEx.zero) {
      HMBToast.error(
        'You cannot invoice a milestone with a zero or negative amount.',
      );
      return;
    }
    // Apply the latest description
    widget.milestone.milestoneDescription = desc;

    await widget.onInvoice(widget.milestone);
    HMBToast.info('Invoice created: #${widget.milestone.invoiceId}');
    setState(() => _isEditable = false);
  }

  void _onSavePressed() {
    widget.milestone.milestoneDescription = descriptionController.text.trim();
    final amt = Money.tryParse(amountController.text, isoCode: 'AUD');
    if (amt == null) {
      HMBToast.error('The amount is invalid');
      return;
    }
    amountController.text = amt.toString();
    widget.milestone.paymentAmount = amt;

    final pct = Percentage.tryParse(percentageController.text);
    if (pct == null) {
      HMBToast.error('The percentage is invalid');
      return;
    }
    percentageController.text = pct.toString();
    widget.milestone.paymentPercentage = pct;

    widget.milestone.edited = true;
    setState(() => _isInEditMode = false);
    widget.onEditingStatusChanged(
      milestone: widget.milestone,
      isEditing: false,
    );
    widget.onSave(widget.milestone);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isOtherTileEditing;
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          title: Text('Milestone ${widget.milestone.milestoneNumber}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.milestone.invoiceId != null)
                FutureBuilderEx<Invoice?>(
                  future: DaoInvoice().getById(widget.milestone.invoiceId),
                  builder: (context, invoice) {
                    final inv = invoice;
                    return inv == null
                        ? const Text('Not Invoiced')
                        // Make invoice number clickable to open InvoiceEditScreen
                        : HMBLinkInternal(
                            label: 'Invoice: ${inv.bestNumber}',
                            navigateTo: () async {
                              final details = await InvoiceDetails.load(inv.id);
                              return InvoiceEditScreen(invoiceDetails: details);
                            },
                          );
                  },
                ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                enabled: _isEditable && !disabled,
                onChanged: (_) => _onDescriptionChanged(),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: percentageController,
                      decoration: const InputDecoration(
                        labelText: 'Percentage',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: _isEditable && !disabled,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      onChanged: (_) => _onPercentageChanged(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: _isEditable && !disabled,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
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
              if (_isInEditMode)
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.green),
                  onPressed: disabled ? null : _onSavePressed,
                  tooltip: 'Save changes',
                )
              else ...[
                if (_isEditable)
                  HMBButtonAdd(
                    onPressed: disabled ? null : _onInvoicePressed,
                    enabled: true,
                    small: true,
                    hint: 'Invoice this Milestone',
                  ),
                if (_isEditable)
                  HMBIconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    enabled: !disabled,
                    onPressed: () async => _onDeletePressed(),
                    hint: 'Delete this Milestone',
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
