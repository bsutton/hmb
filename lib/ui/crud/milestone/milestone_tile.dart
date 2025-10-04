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

// ignore_for_file: discarded_futures

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_invoice.dart';
import '../../../entity/invoice.dart';
import '../../../entity/milestone.dart';
import '../../../util/dart/money_ex.dart';
import '../../dialog/hmb_comfirm_delete_dialog.dart';
import '../../invoicing/edit_invoice_screen.dart';
import '../../invoicing/invoice_details.dart';
import '../../widgets/fields/fields.g.dart';
import '../../widgets/hmb_link_internal.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/icons/hmb_add_button.dart';
import '../../widgets/icons/hmb_delete_icon.dart';
import '../../widgets/icons/hmb_save_icon.dart';
import '../../widgets/layout/layout.g.dart';

class MilestoneTile extends StatefulWidget {
  final Milestone milestone;
  final Money quoteTotal;
  final ValueChanged<Milestone> onDelete;
  final ValueChanged<Milestone> onSave;
  final Future<void> Function(Milestone milestone) onInvoice;
  final void Function({required Milestone milestone, required bool isEditing})
  onEditingStatusChanged;
  final bool isOtherTileEditing;

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

  void _onDeletePressed() {
    showConfirmDeleteDialog(
      context: context,
      nameSingular: 'Milestone',
      question: '''
Are you sure you want to delete ${Strings.isNotBlank(widget.milestone.milestoneDescription) ? widget.milestone.milestoneDescription : 'Milestone ${widget.milestone.milestoneNumber}'}? ''',
      onConfirmed: () async => widget.onDelete(widget.milestone),
    );
  }

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
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: HMBRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT: content fills all available width
              Expanded(
                child: HMBColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== HEADER: title + actions (on the same row) =====
                    HMBRow(
                      children: [
                        Expanded(
                          child: Text(
                            'Milestone ${widget.milestone.milestoneNumber}',
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Tight actions cluster
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isInEditMode)
                              HMBSaveIcon(
                                enabled: !disabled,
                                onPressed: () async => _onSavePressed(),
                                hint: 'Save changes',
                              )
                            else ...[
                              if (_isEditable)
                                HMBButtonAdd(
                                  onAdd: disabled ? null : _onInvoicePressed,
                                  enabled: true,
                                  small: true,
                                  hint: 'Invoice this Milestone',
                                ),
                              if (_isEditable) const SizedBox(width: 8),
                              if (_isEditable)
                                HMBDeleteIcon(
                                  enabled: !disabled,
                                  onPressed: () async => _onDeletePressed(),
                                  hint: 'Delete this Milestone',
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ===== Optional invoice link below header =====
                    if (widget.milestone.invoiceId != null)
                      FutureBuilderEx<Invoice?>(
                        future: DaoInvoice().getById(
                          widget.milestone.invoiceId,
                        ),
                        builder: (context, invoice) {
                          final inv = invoice;
                          return inv == null
                              ? const Text('Not Invoiced')
                              : HMBLinkInternal(
                                  label: 'Invoice: ${inv.bestNumber}',
                                  navigateTo: () async {
                                    final details = await InvoiceDetails.load(
                                      inv.id,
                                    );
                                    return InvoiceEditScreen(
                                      invoiceDetails: details,
                                    );
                                  },
                                );
                        },
                      ),

                    // ===== Fields take the full width =====
                    HMBTextField(
                      controller: descriptionController,
                      labelText: 'Description',
                      enabled: _isEditable && !disabled,
                      onChanged: (_) => _onDescriptionChanged(),
                    ),
                    HMBRow(
                      children: [
                        Expanded(
                          child: HMBTextField(
                            controller: percentageController,
                            labelText: 'Percentage',
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
                        Expanded(
                          child: HMBTextField(
                            controller: amountController,
                            labelText: 'Amount',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
