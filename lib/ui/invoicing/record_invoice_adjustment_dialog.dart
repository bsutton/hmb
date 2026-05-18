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

import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../entity/entity.g.dart';
import '../../util/dart/money_ex.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/hmb_button.dart';

class InvoiceAdjustmentRequest {
  final Money amount;
  final DebtorAdjustmentType adjustmentType;
  final String reason;
  final String? notes;

  const InvoiceAdjustmentRequest({
    required this.amount,
    required this.adjustmentType,
    required this.reason,
    this.notes,
  });
}

Future<InvoiceAdjustmentRequest?> showRecordInvoiceAdjustmentDialog({
  required BuildContext context,
  required Money balance,
}) {
  final amountController = HMBMoneyEditingController(money: balance);
  final reasonController = TextEditingController();
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var adjustmentType = DebtorAdjustmentType.correction;

  return showDialog<InvoiceAdjustmentRequest>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Record Adjustment'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HMBMoneyField(
                controller: amountController,
                labelText: 'Amount',
                fieldName: 'adjustment amount',
                autofocus: true,
              ),
              DropdownButtonFormField<DebtorAdjustmentType>(
                initialValue: adjustmentType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in DebtorAdjustmentType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(_adjustmentTypeLabel(type)),
                    ),
                ],
                onChanged: (value) {
                  adjustmentType = value ?? DebtorAdjustmentType.correction;
                },
              ),
              const SizedBox(height: 12),
              HMBTextField(
                controller: reasonController,
                labelText: 'Reason',
                required: true,
              ),
              HMBTextField(controller: notesController, labelText: 'Notes'),
            ],
          ),
        ),
      ),
      actions: [
        HMBButton(
          label: 'Cancel',
          hint: 'Close without recording an adjustment',
          onPressed: () => Navigator.of(context).pop(),
        ),
        HMBButton(
          label: 'Record',
          hint: 'Record this adjustment against the invoice',
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) {
              return;
            }
            final amount = amountController.money ?? MoneyEx.zero;
            Navigator.of(context).pop(
              InvoiceAdjustmentRequest(
                amount: amount,
                adjustmentType: adjustmentType,
                reason: reasonController.text.trim(),
                notes: _blankToNull(notesController.text),
              ),
            );
          },
        ),
      ],
    ),
  );
}

String _adjustmentTypeLabel(DebtorAdjustmentType type) => switch (type) {
  DebtorAdjustmentType.rounding => 'Rounding',
  DebtorAdjustmentType.writeOff => 'Write-off',
  DebtorAdjustmentType.badDebt => 'Bad debt',
  DebtorAdjustmentType.correction => 'Correction',
  DebtorAdjustmentType.openingBalance => 'Opening balance',
  DebtorAdjustmentType.other => 'Other',
};

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
