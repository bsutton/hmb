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
import '../widgets/layout/layout.g.dart';
import 'payment_method_options.dart';

class PaymentApplicationRequest {
  final int? paymentId;
  final Money? newPaymentAmount;
  final Money amount;
  final DateTime allocatedDate;
  final String? paymentMethod;
  final String? reference;
  final String? notes;

  const PaymentApplicationRequest.existing({
    required this.paymentId,
    required this.amount,
    required this.allocatedDate,
  }) : newPaymentAmount = null,
       paymentMethod = null,
       reference = null,
       notes = null;

  const PaymentApplicationRequest.newPayment({
    required this.newPaymentAmount,
    required this.amount,
    required this.allocatedDate,
    this.paymentMethod,
    this.reference,
    this.notes,
  }) : paymentId = null;

  bool get recordsNewPayment => newPaymentAmount != null;
}

Future<PaymentApplicationRequest?> showApplyPaymentToInvoiceDialog({
  required BuildContext context,
  required List<DebtorPayment> payments,
  required Money balance,
}) async {
  var selected = payments.isEmpty ? null : payments.first;
  var recordNewPayment = false;
  var allocatedDate = DateTime.now();
  final amountController = HMBMoneyEditingController();
  final newPaymentAmountController = HMBMoneyEditingController(money: balance);
  final otherMethodController = TextEditingController();
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final unallocatedByPayment = <int, Money>{};
  final paymentMethods = await loadPaymentMethodOptions();
  var paymentMethod = paymentMethods.first;

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

  if (selected != null) {
    setDefaultAmount(selected);
  } else {
    amountController.money = balance;
  }
  if (!context.mounted) {
    return null;
  }

  return showDialog<PaymentApplicationRequest>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Allocate Payment'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: HMBColumn(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Invoice balance: $balance'),
                if (!recordNewPayment && payments.isEmpty) ...[
                  const Text('No unallocated payments for this customer.'),
                  const Text(
                    'Record a new payment to allocate money to this invoice.',
                  ),
                ] else if (!recordNewPayment) ...[
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
                  HMBMoneyField(
                    controller: amountController,
                    labelText: 'Amount to allocate',
                    fieldName: 'payment allocation amount',
                  ),
                  HMBDateTimeField(
                    label: 'Allocation date',
                    initialDateTime: allocatedDate,
                    mode: HMBDateTimeFieldMode.dateOnly,
                    onChanged: (date) => allocatedDate = date,
                  ),
                ] else ...[
                  HMBMoneyField(
                    controller: newPaymentAmountController,
                    labelText: 'Payment amount',
                    fieldName: 'payment amount',
                  ),
                  HMBDateTimeField(
                    label: 'Payment date',
                    initialDateTime: allocatedDate,
                    mode: HMBDateTimeFieldMode.dateOnly,
                    onChanged: (date) => allocatedDate = date,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Method'),
                    items: [
                      for (final method in paymentMethods)
                        DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => paymentMethod = value);
                    },
                  ),
                  if (paymentMethod == otherPaymentMethod)
                    HMBTextField(
                      controller: otherMethodController,
                      labelText: 'Other method',
                      validator: (value) {
                        if (_blankToNull(value ?? '') == null) {
                          return 'Please enter the payment method';
                        }
                        return null;
                      },
                    ),
                  HMBTextField(
                    controller: referenceController,
                    labelText: 'Reference',
                  ),
                  HMBTextField(controller: notesController, labelText: 'Notes'),
                  const Text(
                    'The invoice balance will be allocated. Any extra payment '
                    'amount will remain unallocated.',
                  ),
                ],
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
          if (payments.isNotEmpty || !recordNewPayment)
            HMBButton(
              label: recordNewPayment ? 'Use Existing' : 'Record New',
              hint: recordNewPayment
                  ? 'Allocate an existing unallocated payment'
                  : 'Record a new payment for this invoice',
              onPressed: () => setState(() {
                recordNewPayment = !recordNewPayment;
                if (!recordNewPayment && selected != null) {
                  setDefaultAmount(selected!);
                }
              }),
            ),
          if (recordNewPayment || payments.isNotEmpty)
            HMBButton(
              label: recordNewPayment ? 'Record' : 'Apply',
              hint: recordNewPayment
                  ? 'Record this payment and allocate it to the invoice'
                  : 'Apply this payment to the invoice',
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }
                if (recordNewPayment) {
                  final paymentAmount =
                      newPaymentAmountController.money ?? MoneyEx.zero;
                  if (!paymentAmount.isPositive) {
                    return;
                  }
                  Navigator.of(context).pop(
                    PaymentApplicationRequest.newPayment(
                      newPaymentAmount: paymentAmount,
                      amount: paymentAmount < balance ? paymentAmount : balance,
                      allocatedDate: allocatedDate,
                      paymentMethod: selectedPaymentMethod(
                        paymentMethod,
                        otherMethodController.text,
                      ),
                      reference: _blankToNull(referenceController.text),
                      notes: _blankToNull(notesController.text),
                    ),
                  );
                } else {
                  final payment = selected;
                  if (payment == null) {
                    return;
                  }
                  final amount = amountController.money ?? MoneyEx.zero;
                  final unallocated =
                      unallocatedByPayment[payment.id] ?? MoneyEx.zero;
                  if (amount > balance || amount > unallocated) {
                    return;
                  }
                  Navigator.of(context).pop(
                    PaymentApplicationRequest.existing(
                      paymentId: payment.id,
                      amount: amount,
                      allocatedDate: allocatedDate,
                    ),
                  );
                }
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

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
