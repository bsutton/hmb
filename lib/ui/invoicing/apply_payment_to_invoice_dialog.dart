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

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/format.dart';
import '../../util/dart/money_ex.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_date_time_picker.dart';

class PaymentApplicationRequest {
  final int paymentId;
  final Money amount;
  final DateTime allocatedDate;

  const PaymentApplicationRequest({
    required this.paymentId,
    required this.amount,
    required this.allocatedDate,
  });
}

Future<PaymentApplicationRequest?> showApplyPaymentToInvoiceDialog({
  required BuildContext context,
  required List<DebtorPayment> payments,
  required Money balance,
}) async {
  if (payments.isEmpty) {
    return showDialog<PaymentApplicationRequest>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Payment'),
        content: const Text('No unallocated payments for this customer.'),
        actions: [
          HMBButton(
            label: 'Close',
            hint: 'Close this dialog',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  var selected = payments.first;
  var allocatedDate = DateTime.now();
  final amountController = HMBMoneyEditingController();
  final formKey = GlobalKey<FormState>();
  final unallocatedByPayment = <int, Money>{};

  final ledger = DebtorLedgerService();
  for (final payment in payments) {
    unallocatedByPayment[payment.id] = await ledger.paymentUnallocatedAmount(
      payment,
    );
  }

  Money defaultAmount(DebtorPayment payment) {
    final unallocated = unallocatedByPayment[payment.id] ?? MoneyEx.zero;
    return unallocated < balance ? unallocated : balance;
  }

  void setDefaultAmount(DebtorPayment payment) =>
      amountController.money = defaultAmount(payment);

  setDefaultAmount(selected);
  if (!context.mounted) {
    return null;
  }

  return showDialog<PaymentApplicationRequest>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Apply Payment'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<DebtorPayment>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Payment',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final payment in payments)
                      DropdownMenuItem(
                        value: payment,
                        child: Text(_paymentLabel(payment)),
                      ),
                  ],
                  onChanged: (payment) {
                    if (payment == null) {
                      return;
                    }
                    setState(() {
                      selected = payment;
                      setDefaultAmount(payment);
                    });
                  },
                ),
                const SizedBox(height: 12),
                HMBMoneyField(
                  controller: amountController,
                  labelText: 'Amount',
                  fieldName: 'payment allocation amount',
                ),
                HMBDateTimeField(
                  label: 'Date',
                  initialDateTime: allocatedDate,
                  mode: HMBDateTimeFieldMode.dateOnly,
                  onChanged: (date) => allocatedDate = date,
                ),
              ],
            ),
          ),
        ),
        actions: [
          HMBButton(
            label: 'Cancel',
            hint: 'Close without applying a payment',
            onPressed: () => Navigator.of(context).pop(),
          ),
          HMBButton(
            label: 'Apply',
            hint: 'Apply this payment to the invoice',
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              final amount = amountController.money ?? MoneyEx.zero;
              final unallocated =
                  unallocatedByPayment[selected.id] ?? MoneyEx.zero;
              if (amount > balance || amount > unallocated) {
                return;
              }
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pop(
                PaymentApplicationRequest(
                  paymentId: selected.id,
                  amount: amount,
                  allocatedDate: allocatedDate,
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

String _paymentLabel(DebtorPayment payment) {
  final parts = [
    formatDate(payment.paymentDate),
    payment.amount.toString(),
    payment.reference,
  ].nonNulls;
  return parts.join(' - ');
}
