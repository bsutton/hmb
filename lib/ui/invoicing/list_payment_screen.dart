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
import '../dialog/hmb_comfirm_delete_dialog.dart';
import '../nav/dashboards/accounting/accounting_period_selector.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_date_time_picker.dart';
import '../widgets/hmb_search.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/icons/hmb_add_button.dart';
import '../widgets/icons/hmb_delete_icon.dart';
import '../widgets/icons/hmb_filter_icon.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/layout/surface.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/select/hmb_filter_sheet.dart';
import '../widgets/select/hmb_select_contact.dart';
import '../widgets/select/hmb_select_customer.dart';
import 'payment_method_options.dart';

enum _PaymentSortOrder {
  newest('Newest first'),
  oldest('Oldest first'),
  customer('Customer'),
  amount('Amount');

  const _PaymentSortOrder(this.label);

  final String label;
}

class PaymentListScreen extends StatefulWidget {
  const PaymentListScreen({super.key});

  @override
  State<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends State<PaymentListScreen> {
  final _selectedCustomer = SelectedCustomer();
  final _searchController = HMBSearchController();
  var _period = AccountingPeriod.forMonth(DateTime.now());
  var _includeFullyAllocated = true;
  var _search = '';
  var _sortOrder = _PaymentSortOrder.newest;
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
    final where = <String>['p.payment_date >= ?', 'p.payment_date < ?'];
    final args = <Object?>[
      _period.startInclusive.toIso8601String(),
      _period.endExclusive.toIso8601String(),
    ];

    final customerId = _selectedCustomer.customerId;
    if (customerId != null) {
      where.add('p.customer_id = ?');
      args.add(customerId);
    }
    if (!_includeFullyAllocated) {
      where.add('IFNULL(a.allocated, 0) < p.amount');
    }
    final search = _search.trim().toLowerCase();
    if (search.isNotEmpty) {
      where.add('''
(
  LOWER(IFNULL(c.name, '')) LIKE ?
  OR LOWER(IFNULL(ct.firstName, '')) LIKE ?
  OR LOWER(IFNULL(ct.surname, '')) LIKE ?
  OR LOWER(IFNULL(p.payment_method, '')) LIKE ?
  OR LOWER(IFNULL(p.reference, '')) LIKE ?
  OR LOWER(IFNULL(p.notes, '')) LIKE ?
  OR LOWER(IFNULL(p.external_provider, '')) LIKE ?
  OR LOWER(IFNULL(p.external_payment_id, '')) LIKE ?
)
''');
      args.addAll(List.filled(8, '%$search%'));
    }

    final orderBy = switch (_sortOrder) {
      _PaymentSortOrder.newest => 'p.payment_date DESC, p.id DESC',
      _PaymentSortOrder.oldest => 'p.payment_date ASC, p.id ASC',
      _PaymentSortOrder.customer =>
        'LOWER(IFNULL(c.name, "")) ASC, p.payment_date DESC, p.id DESC',
      _PaymentSortOrder.amount => 'p.amount DESC, p.payment_date DESC',
    };

    final db = DaoDebtorPayment().withoutTransaction();
    final rows = await db.rawQuery('''
SELECT
  p.*,
  IFNULL(a.allocated, 0) AS allocated,
  IFNULL(c.name, 'No customer') AS customer_name,
  TRIM(IFNULL(ct.firstName, '') || ' ' || IFNULL(ct.surname, ''))
    AS contact_name
FROM debtor_payment p
LEFT JOIN (
  SELECT payment_id, SUM(amount) AS allocated
  FROM debtor_payment_allocation
  GROUP BY payment_id
) a ON a.payment_id = p.id
LEFT JOIN customer c ON c.id = p.customer_id
LEFT JOIN contact ct ON ct.id = p.contact_id
WHERE ${where.join('\nAND ')}
ORDER BY $orderBy
''', args);

    return [
      for (final row in rows)
        _PaymentRow(
          payment: DebtorPayment.fromMap(row),
          customerName: (row['customer_name'] as String?) ?? 'No customer',
          contactName: _blankToNull(row['contact_name'] as String? ?? ''),
          allocated: MoneyEx.fromInt(row['allocated'] as int? ?? 0),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customer Payments')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: HMBSearch(
                  controller: _searchController,
                  onSearch: (filter) async {
                    setState(() {
                      _search = filter?.trim().toLowerCase() ?? '';
                      _reload();
                    });
                  },
                ),
              ),
              HMBButtonAdd(
                enabled: true,
                onAdd: _addPayment,
                hint: 'Record a customer payment before or after invoicing',
              ),
              HMBFilterIcon(
                active: _isFilterActive(),
                onPressed: _showFilterSheet,
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
                return HMBColumn(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _summaryCard(rows),
                    const Surface(child: Text('No payments found.')),
                  ],
                );
              }
              return HMBColumn(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summaryCard(rows),
                  for (final row in rows) _paymentCard(row),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _summaryCard(List<_PaymentRow> rows) => Surface(
    elevation: SurfaceElevation.e1,
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total received', style: Theme.of(context).textTheme.titleSmall),
        Text(
          '${_periodLabel(_period)}: ${_total(rows)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );

  Widget _paymentCard(_PaymentRow row) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GestureDetector(
      onTap: () => _showPaymentDetails(row),
      child: Surface(
        elevation: SurfaceElevation.e1,
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.customerName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(formatDate(row.payment.paymentDate, format: 'j M Y')),
                if (row.contactName != null) Text(row.contactName!),
                Text('Amount: ${row.payment.amount}'),
                Text('Allocated: ${row.allocated}'),
                Text('Unallocated: ${row.unallocated}'),
              ],
            ),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (row.payment.paymentMethod != null)
                  Text(row.payment.paymentMethod!),
                if (row.payment.reference != null) Text(row.payment.reference!),
                _sourceWidget(row),
                if (row.payment.notes != null) Text(row.payment.notes!),
                if (row.unallocated.isPositive)
                  HMBButton.withIcon(
                    label: 'Allocate',
                    hint: 'Allocate this payment to an invoice',
                    icon: const Icon(Icons.call_split),
                    onPressed: () => _allocatePayment(row),
                  ),
                HMBButton.withIcon(
                  label: 'Allocations',
                  hint: 'Show allocations for this payment',
                  icon: const Icon(Icons.receipt_long),
                  onPressed: () => _showPaymentDetails(row),
                ),
                HMBDeleteIcon(
                  hint: 'Delete this payment',
                  onPressed: () => _confirmDeletePayment(row),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _sourceWidget(_PaymentRow row) {
    if (!row.hasExternalSource) {
      return const Text('Source: Manual');
    }
    return InkWell(
      onTap: () => _showSourceDetails(row),
      child: Text(
        'Source: ${row.sourceLabel}',
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Future<void> _showSourceDetails(_PaymentRow row) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(row.sourceLabel),
        content: HMBColumn(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provider: ${row.sourceLabel}'),
            if (row.payment.externalPaymentId != null)
              Text('Reference: ${row.payment.externalPaymentId}'),
          ],
        ),
        actions: [
          HMBButton(
            label: 'Close',
            hint: 'Close source details',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentDetails(_PaymentRow row) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Allocations'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilderEx<List<_PaymentAllocationRow>>(
            future: _loadPaymentAllocations(row.payment.id),
            waitingBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            builder: (context, allocations) {
              if (allocations == null) {
                return const SizedBox.shrink();
              }
              return SingleChildScrollView(
                child: HMBColumn(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Surface(
                      elevation: SurfaceElevation.e2,
                      child: HMBColumn(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Summary',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              Text('Payment: ${row.payment.amount}'),
                              Text('Allocated: ${row.allocated}'),
                              Text('Unallocated: ${row.unallocated}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (allocations.isEmpty)
                      const Surface(
                        elevation: SurfaceElevation.e1,
                        child: Text('No allocations recorded.'),
                      )
                    else
                      const Text(
                        'Allocations',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (allocations.isNotEmpty)
                      for (final allocation in allocations)
                        _allocationLine(allocation, row),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          if (row.unallocated.isPositive)
            HMBButton(
              label: 'Allocate',
              hint: 'Allocate this payment to an invoice',
              onPressed: () async {
                Navigator.of(context).pop();
                await _allocatePayment(row);
              },
            ),
          HMBButton(
            label: 'Close',
            hint: 'Close payment allocations',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _allocationLine(
    _PaymentAllocationRow row,
    _PaymentRow paymentRow,
  ) => Surface(
    elevation: SurfaceElevation.e1,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.receipt_long, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.invoiceLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (row.jobSummary != null) Text(row.jobSummary!),
              Text(
                'Allocation date: '
                '${formatDate(row.allocation.allocatedDate, format: 'j M Y')}',
              ),
            ],
          ),
        ),
        Text(
          row.allocation.amount.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        HMBDeleteIcon(
          hint: 'Delete this allocation',
          onPressed: () => _confirmDeleteAllocation(row, paymentRow),
        ),
      ],
    ),
  );

  Future<void> _confirmDeletePayment(_PaymentRow row) async {
    await showConfirmDeleteDialog(
      context: context,
      nameSingular: 'payment',
      child: Text(
        'Delete this payment for ${row.payment.amount}? '
        'Any allocations for this payment will also be deleted.',
      ),
      onConfirmed: () async {
        await DebtorLedgerService().deletePayment(row.payment.id);
        _reload();
        if (mounted) {
          HMBToast.info('Payment deleted');
          setState(() {});
        }
      },
    );
  }

  Future<void> _confirmDeleteAllocation(
    _PaymentAllocationRow row,
    _PaymentRow paymentRow,
  ) async {
    var deleted = false;
    await showConfirmDeleteDialog(
      context: context,
      nameSingular: 'payment allocation',
      child: Text(
        'Delete the ${row.allocation.amount} allocation to '
        '${row.invoiceLabel}?',
      ),
      onConfirmed: () async {
        await DebtorLedgerService().deletePaymentAllocation(row.allocation.id);
        deleted = true;
        _reload();
        if (mounted) {
          HMBToast.info('Payment allocation deleted');
          setState(() {});
        }
      },
    );
    if (deleted && mounted) {
      Navigator.of(context).pop();
      await _showPaymentDetails(
        _PaymentRow(
          payment: paymentRow.payment,
          customerName: paymentRow.customerName,
          contactName: paymentRow.contactName,
          allocated: paymentRow.allocated - row.allocation.amount,
        ),
      );
    }
  }

  Future<List<_PaymentAllocationRow>> _loadPaymentAllocations(
    int paymentId,
  ) async {
    final db = DaoPaymentAllocation().withoutTransaction();
    final rows = await db.rawQuery(
      '''
SELECT
  pa.*,
  i.invoice_num,
  i.id AS invoice_id,
  j.summary AS job_summary
FROM debtor_payment_allocation pa
LEFT JOIN invoice i ON i.id = pa.invoice_id
LEFT JOIN job j ON j.id = i.job_id
WHERE pa.payment_id = ?
ORDER BY pa.allocated_date ASC, pa.id ASC
''',
      [paymentId],
    );
    return [
      for (final row in rows)
        _PaymentAllocationRow(
          allocation: PaymentAllocation.fromMap(row),
          invoiceLabel: _invoiceLabel(
            invoiceId: row['invoice_id'] as int?,
            invoiceNum: row['invoice_num'] as String?,
          ),
          jobSummary: _blankToNull(row['job_summary'] as String? ?? ''),
        ),
    ];
  }

  Future<void> _allocatePayment(_PaymentRow row) async {
    final request = await showAllocatePaymentDialog(
      context: context,
      payment: row.payment,
      unallocated: row.unallocated,
    );
    if (request == null) {
      return;
    }
    try {
      await DebtorLedgerService().applyPaymentToInvoice(
        paymentId: row.payment.id,
        invoiceId: request.invoiceId,
        amount: request.amount,
        allocatedDate: request.allocatedDate,
      );
      _reload();
      if (!mounted) {
        return;
      }
      HMBToast.info('Payment allocated');
      setState(() {});
    } catch (e) {
      HMBToast.error(
        'Failed to allocate payment: $e',
        acknowledgmentRequired: true,
      );
    }
  }

  Future<void> _showFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => HMBFilterSheet(
        onReset: () {
          setState(() {
            _selectedCustomer.customerId = null;
            _period = AccountingPeriod.forMonth(DateTime.now());
            _includeFullyAllocated = true;
            _sortOrder = _PaymentSortOrder.newest;
            _reload();
          });
        },
        contentBuilder: (_) => StatefulBuilder(
          builder: (context, setSheetState) => HMBColumn(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccountingPeriodSelector(
                initialPeriod: _period,
                onChanged: (period) {
                  setState(() {
                    _period = period;
                    _reload();
                  });
                  setSheetState(() {});
                },
              ),
              HMBSelectCustomer(
                selectedCustomer: _selectedCustomer,
                showAdd: false,
                onSelected: (_) {
                  setState(_reload);
                  setSheetState(() {});
                },
              ),
              HMBDroplist<_PaymentSortOrder>(
                title: 'Sort order',
                selectedItem: () async => _sortOrder,
                items: (_) async => _PaymentSortOrder.values,
                format: (sortOrder) => sortOrder.label,
                onChanged: (sortOrder) {
                  setState(() {
                    _sortOrder = sortOrder ?? _PaymentSortOrder.newest;
                    _reload();
                  });
                  setSheetState(() {});
                },
                showSearch: false,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show allocated payments'),
                value: _includeFullyAllocated,
                onChanged: (value) {
                  setState(() {
                    _includeFullyAllocated = value ?? true;
                    _reload();
                  });
                  setSheetState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isFilterActive() {
    final currentMonth = AccountingPeriod.forMonth(DateTime.now());
    return _selectedCustomer.customerId != null ||
        !_includeFullyAllocated ||
        _sortOrder != _PaymentSortOrder.newest ||
        _period.startInclusive != currentMonth.startInclusive ||
        _period.endExclusive != currentMonth.endExclusive;
  }

  Money _total(List<_PaymentRow> rows) =>
      rows.fold(MoneyEx.zero, (total, row) => total + row.payment.amount);

  String _periodLabel(AccountingPeriod period) {
    final end = period.endExclusive.subtract(const Duration(days: 1));
    final includeYear =
        period.startInclusive.year != DateTime.now().year ||
        end.year != DateTime.now().year;
    final format = includeYear ? 'j M Y' : 'j M';
    return '${formatDate(period.startInclusive, format: format)} to '
        '${formatDate(end, format: format)}';
  }

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

  const _PaymentRow({
    required this.payment,
    required this.customerName,
    required this.contactName,
    required this.allocated,
  });

  Money get unallocated => payment.amount - allocated;

  bool get hasExternalSource =>
      payment.externalProvider != null && payment.externalProvider!.isNotEmpty;

  String get sourceLabel {
    final provider = payment.externalProvider?.trim();
    if (provider == null || provider.isEmpty) {
      return 'Manual';
    }
    return provider.substring(0, 1).toUpperCase() + provider.substring(1);
  }
}

class _PaymentAllocationRow {
  final PaymentAllocation allocation;
  final String invoiceLabel;
  final String? jobSummary;

  const _PaymentAllocationRow({
    required this.allocation,
    required this.invoiceLabel,
    required this.jobSummary,
  });
}

class _InvoiceAllocationOption {
  final Invoice invoice;
  final Money balance;
  final String? jobSummary;

  const _InvoiceAllocationOption({
    required this.invoice,
    required this.balance,
    required this.jobSummary,
  });

  String get label {
    final parts = [
      _invoiceLabel(invoiceId: invoice.id, invoiceNum: invoice.invoiceNum),
      jobSummary,
      'Balance: $balance',
    ].nonNulls;
    return parts.join(' - ');
  }
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

class PaymentAllocationRequest {
  final int invoiceId;
  final Money amount;
  final DateTime allocatedDate;

  const PaymentAllocationRequest({
    required this.invoiceId,
    required this.amount,
    required this.allocatedDate,
  });
}

Future<CustomerPaymentRequest?> showRecordCustomerPaymentDialog({
  required BuildContext context,
}) async {
  final paymentMethods = await loadPaymentMethodOptions();
  if (!context.mounted) {
    return null;
  }
  final selectedCustomer = SelectedCustomer();
  final amountController = HMBMoneyEditingController();
  final otherMethodController = TextEditingController();
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  Customer? customer;
  Contact? contact;
  var paymentMethod = paymentMethods.first;
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
            child: HMBColumn(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  paymentMethod: selectedPaymentMethod(
                    paymentMethod,
                    otherMethodController.text,
                  ),
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

Future<PaymentAllocationRequest?> showAllocatePaymentDialog({
  required BuildContext context,
  required DebtorPayment payment,
  required Money unallocated,
}) async {
  final options = await _loadInvoiceAllocationOptions(payment);
  if (!context.mounted) {
    return null;
  }
  if (options.isEmpty) {
    return showDialog<PaymentAllocationRequest>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allocate Payment'),
        content: const Text('No unpaid invoices for this customer.'),
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

  var selected = _defaultInvoiceOption(options, unallocated);
  var allocatedDate = DateTime.now();
  final amountController = HMBMoneyEditingController();
  final formKey = GlobalKey<FormState>();

  Money defaultAmount(_InvoiceAllocationOption option) =>
      option.balance < unallocated ? option.balance : unallocated;

  void setDefaultAmount(_InvoiceAllocationOption option) =>
      amountController.money = defaultAmount(option);

  setDefaultAmount(selected);

  return showDialog<PaymentAllocationRequest>(
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
                Text('Unallocated: $unallocated'),
                DropdownButtonFormField<_InvoiceAllocationOption>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Invoice'),
                  items: [
                    for (final option in options)
                      DropdownMenuItem<_InvoiceAllocationOption>(
                        value: option,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (option) {
                    if (option == null) {
                      return;
                    }
                    setState(() {
                      selected = option;
                      setDefaultAmount(option);
                    });
                  },
                ),
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
            hint: 'Close without allocating this payment',
            onPressed: () => Navigator.of(context).pop(),
          ),
          HMBButton(
            label: 'Allocate',
            hint: 'Allocate this payment to the selected invoice',
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              final amount = amountController.money ?? MoneyEx.zero;
              if (amount > unallocated || amount > selected.balance) {
                HMBToast.error(
                  'Allocation exceeds the payment or invoice balance.',
                );
                return;
              }
              Navigator.of(context).pop(
                PaymentAllocationRequest(
                  invoiceId: selected.invoice.id,
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

Future<List<_InvoiceAllocationOption>> _loadInvoiceAllocationOptions(
  DebtorPayment payment,
) async {
  final customerId = payment.customerId;
  if (customerId == null) {
    return [];
  }
  final db = DaoInvoice().withoutTransaction();
  final rows = await db.rawQuery(
    '''
WITH invoice_balances AS (
  SELECT
    i.*,
    j.summary AS job_summary,
    (
      i.total_amount
      - IFNULL(pa.paid, 0)
      - IFNULL(ca.credited, 0)
      - IFNULL(da.adjusted, 0)
    ) AS balance
  FROM invoice i
  JOIN job j ON j.id = i.job_id
  LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS paid
    FROM debtor_payment_allocation
    GROUP BY invoice_id
  ) pa ON pa.invoice_id = i.id
  LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS credited
    FROM credit_allocation
    GROUP BY invoice_id
  ) ca ON ca.invoice_id = i.id
  LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS adjusted
    FROM debtor_adjustment
    GROUP BY invoice_id
  ) da ON da.invoice_id = i.id
  WHERE j.customer_id = ?
    AND IFNULL(i.paid, 0) = 0
    AND IFNULL(i.external_sync_status, 0) NOT IN (?, ?)
)
SELECT *
FROM invoice_balances
WHERE balance > 0
ORDER BY IFNULL(due_date, created_date) ASC, id ASC
''',
    [
      customerId,
      InvoiceExternalSyncStatus.deleted.ordinal,
      InvoiceExternalSyncStatus.voided.ordinal,
    ],
  );
  return [
    for (final row in rows)
      _InvoiceAllocationOption(
        invoice: Invoice.fromMap(row),
        balance: MoneyEx.fromInt(row['balance'] as int? ?? 0),
        jobSummary: _blankToNull(row['job_summary'] as String? ?? ''),
      ),
  ];
}

_InvoiceAllocationOption _defaultInvoiceOption(
  List<_InvoiceAllocationOption> options,
  Money unallocated,
) => options.firstWhere(
  (option) => option.balance == unallocated,
  orElse: () => options.first,
);

String _invoiceLabel({required int? invoiceId, required String? invoiceNum}) {
  if (_blankToNull(invoiceNum ?? '') != null) {
    return 'Invoice $invoiceNum';
  }
  return invoiceId == null ? 'Invoice' : 'Invoice #$invoiceId';
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
