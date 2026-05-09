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

import '../../util/dart/money_ex.dart';
import '../test_keys.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/hmb_button.dart';

class InvoicePaymentRequest {
  final Money amount;
  final String? paymentMethod;
  final String? reference;
  final String? notes;

  const InvoicePaymentRequest({
    required this.amount,
    this.paymentMethod,
    this.reference,
    this.notes,
  });
}

Future<InvoicePaymentRequest?> showRecordInvoicePaymentDialog({
  required BuildContext context,
  required Money balance,
}) {
  final amountController = HMBMoneyEditingController(money: balance);
  final methodController = TextEditingController();
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<InvoicePaymentRequest>(
    context: context,
    builder: (context) {
      String? amountError;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Record Payment'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HMBMoneyField(
                    controller: amountController,
                    labelText: 'Amount',
                    fieldName: 'payment amount',
                    fieldKey: TestKeys.recordPaymentAmountField,
                    autofocus: true,
                    onChanged: (_) => setState(() => amountError = null),
                  ),
                  if (amountError != null)
                    Text(
                      amountError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  HMBTextField(
                    controller: methodController,
                    labelText: 'Method',
                    fieldKey: TestKeys.recordPaymentMethodField,
                  ),
                  HMBTextField(
                    controller: referenceController,
                    labelText: 'Reference',
                    fieldKey: TestKeys.recordPaymentReferenceField,
                  ),
                  HMBTextField(
                    controller: notesController,
                    labelText: 'Notes',
                    fieldKey: TestKeys.recordPaymentNotesField,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            HMBButton(
              label: 'Cancel',
              hint: 'Close without recording a payment',
              onPressed: () => Navigator.of(context).pop(),
            ),
            HMBButton(
              label: 'Record',
              hint: 'Record this payment against the invoice',
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }
                final amount = amountController.money ?? MoneyEx.zero;
                if (amount > balance) {
                  setState(() {
                    amountError =
                        'Payment cannot exceed the invoice balance ($balance).';
                  });
                  return;
                }
                Navigator.of(context).pop(
                  InvoicePaymentRequest(
                    amount: amount,
                    paymentMethod: _blankToNull(methodController.text),
                    reference: _blankToNull(referenceController.text),
                    notes: _blankToNull(notesController.text),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
