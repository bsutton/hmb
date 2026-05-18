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
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/format.dart';
import '../../util/dart/money_ex.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_date_time_picker.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/layout/surface.dart';
import '../widgets/select/hmb_select_contact.dart';
import '../widgets/select/hmb_select_customer.dart';

class PaymentListScreen extends StatefulWidget {
  const PaymentListScreen({super.key});

  @override
  State<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends State<PaymentListScreen> {
  var _includeFullyAllocated = true;
  late Future<List<_PaymentRow>> _rows;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _rows = _loadRows();
  }

  Future<List<_PaymentRow>> _loadRows() async {
    final payments = await DaoDebtorPayment().getRecent(
      includeFullyAllocated: _includeFullyAllocated,
    );
    final rows = <_PaymentRow>[];
    final ledger = DebtorLedgerService();
    for (final payment in payments) {
      final customer = await DaoCustomer().getById(payment.customerId);
      final contact = await DaoContact().getById(payment.contactId);
      final allocated = await ledger.paymentAllocatedAmount(payment.id);
      rows.add(
        _PaymentRow(
          payment: payment,
          customerName: customer?.name ?? 'No customer',
          contactName: contact == null
              ? null
              : '${contact.firstName} ${contact.surname}',
          allocated: allocated,
          unallocated: payment.amount - allocated,
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payments')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              HMBButton.withIcon(
                label: 'Add Payment',
                hint: 'Record a customer payment before or after invoicing',
                icon: const Icon(Icons.add),
                onPressed: _addPayment,
              ),
              FilterChip(
                label: const Text('Show allocated'),
                selected: _includeFullyAllocated,
                onSelected: (value) => setState(() {
                  _includeFullyAllocated = value;
                  _reload();
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilderEx<List<_PaymentRow>>(
            future: _rows,
            waitingBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            builder: (context, rows) {
              if (rows == null) {
                return const SizedBox.shrink();
              }
              if (rows.isEmpty) {
                return const Surface(child: Text('No payments found.'));
              }
              return HMBColumn(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final row in rows) _paymentCard(row)],
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _paymentCard(_PaymentRow row) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Surface(
      elevation: SurfaceElevation.e1,
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.customerName, style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(formatDate(row.payment.paymentDate)),
              if (row.contactName != null) Text(row.contactName!),
              Text('Amount: ${row.payment.amount}'),
              Text('Allocated: ${row.allocated}'),
              Text('Unallocated: ${row.unallocated}'),
            ],
          ),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (row.payment.paymentMethod != null)
                Text(row.payment.paymentMethod!),
              if (row.payment.reference != null) Text(row.payment.reference!),
              if (row.payment.notes != null) Text(row.payment.notes!),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _addPayment() async {
    final request = await showRecordCustomerPaymentDialog(context: context);
    if (request == null) {
      return;
    }
    try {
      await DebtorLedgerService().recordUnallocatedPayment(
        customerId: request.customerId,
        contactId: request.contactId,
        amount: request.amount,
        paymentDate: request.paymentDate,
        paymentMethod: request.paymentMethod,
        reference: request.reference,
        notes: request.notes,
      );
      _reload();
      if (!mounted) {
        return;
      }
      HMBToast.info('Payment recorded');
      setState(() {});
    } catch (e) {
      HMBToast.error(
        'Failed to record payment: $e',
        acknowledgmentRequired: true,
      );
    }
  }
}

class _PaymentRow {
  final DebtorPayment payment;
  final String customerName;
  final String? contactName;
  final Money allocated;
  final Money unallocated;

  const _PaymentRow({
    required this.payment,
    required this.customerName,
    required this.contactName,
    required this.allocated,
    required this.unallocated,
  });
}

class CustomerPaymentRequest {
  final int customerId;
  final int? contactId;
  final DateTime paymentDate;
  final Money amount;
  final String? paymentMethod;
  final String? reference;
  final String? notes;

  const CustomerPaymentRequest({
    required this.customerId,
    required this.paymentDate,
    required this.amount,
    this.contactId,
    this.paymentMethod,
    this.reference,
    this.notes,
  });
}

Future<CustomerPaymentRequest?> showRecordCustomerPaymentDialog({
  required BuildContext context,
}) {
  final selectedCustomer = SelectedCustomer();
  final amountController = HMBMoneyEditingController();
  final methodController = TextEditingController();
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  Customer? customer;
  Contact? contact;
  var paymentDate = DateTime.now();
  var showCustomerError = false;

  return showDialog<CustomerPaymentRequest>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Record Payment'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HMBSelectCustomer(
                  selectedCustomer: selectedCustomer,
                  required: true,
                  onSelected: (value) => setState(() {
                    customer = value;
                    contact = null;
                    showCustomerError = false;
                  }),
                ),
                if (showCustomerError)
                  Text(
                    'Please select a customer',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                HMBSelectContact(
                  key: ValueKey(customer?.id),
                  initialContact: contact?.id,
                  customer: customer,
                  onSelected: (value) => contact = value,
                ),
                HMBDateTimeField(
                  label: 'Date',
                  initialDateTime: paymentDate,
                  mode: HMBDateTimeFieldMode.dateOnly,
                  onChanged: (date) => paymentDate = date,
                ),
                HMBMoneyField(
                  controller: amountController,
                  labelText: 'Amount',
                  fieldName: 'payment amount',
                  autofocus: true,
                ),
                HMBTextField(controller: methodController, labelText: 'Method'),
                HMBTextField(
                  controller: referenceController,
                  labelText: 'Reference',
                ),
                HMBTextField(controller: notesController, labelText: 'Notes'),
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
            hint: 'Record this customer payment',
            onPressed: () {
              if (customer == null) {
                setState(() => showCustomerError = true);
                return;
              }
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              Navigator.of(context).pop(
                CustomerPaymentRequest(
                  customerId: customer!.id,
                  contactId: contact?.id,
                  paymentDate: paymentDate,
                  amount: amountController.money ?? MoneyEx.zero,
                  paymentMethod: _blankToNull(methodController.text),
                  reference: _blankToNull(referenceController.text),
                  notes: _blankToNull(notesController.text),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
