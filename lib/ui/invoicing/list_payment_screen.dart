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
import '../nav/dashboards/accounting/accounting_period_selector.dart';
import '../nav/dashboards/accounting/report_csv_export.dart';
import '../widgets/fields/fields.g.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_date_time_picker.dart';
import '../widgets/hmb_search.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/icons/hmb_add_button.dart';
import '../widgets/icons/hmb_filter_icon.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/layout/surface.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/select/hmb_filter_sheet.dart';
import '../widgets/select/hmb_select_contact.dart';
import '../widgets/select/hmb_select_customer.dart';

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
    appBar: AppBar(title: const Text('Payments')),
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
                  _exportActions(rows),
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

  Widget _exportActions(List<_PaymentRow> rows) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      HMBButton.withIcon(
        label: 'Send CSV',
        hint: 'Send the visible customer payments as a CSV report',
        icon: const Icon(Icons.table_view),
        onPressed: () => _sendCsv(rows),
      ),
      HMBButton.withIcon(
        label: 'View/Send PDF',
        hint: 'View and send the visible customer payments as a PDF report',
        icon: const Icon(Icons.picture_as_pdf),
        onPressed: () => _viewSendPdf(rows),
      ),
    ],
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
            children: [
              if (row.payment.paymentMethod != null)
                Text(row.payment.paymentMethod!),
              if (row.payment.reference != null) Text(row.payment.reference!),
              _sourceWidget(row),
              if (row.payment.notes != null) Text(row.payment.notes!),
            ],
          ),
        ],
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

  String _fileName({required String extension}) =>
      accountingReportExportFileName(
        reportName: 'customer_payments',
        extension: extension,
        startInclusive: _period.startInclusive,
        endInclusive: _period.endExclusive.subtract(const Duration(days: 1)),
      );

  List<List<String>> _exportRows(List<_PaymentRow> rows) => [
    [
      'Date',
      'Customer',
      'Contact',
      'Method',
      'Reference',
      'Source',
      'Amount',
      'Allocated',
      'Unallocated',
    ],
    for (final row in rows)
      [
        formatDate(row.payment.paymentDate, format: 'j M Y'),
        row.customerName,
        row.contactName ?? '',
        row.payment.paymentMethod ?? '',
        row.payment.reference ?? '',
        row.sourceLabel,
        row.payment.amount.toString(),
        row.allocated.toString(),
        row.unallocated.toString(),
      ],
  ];

  String _csv(List<_PaymentRow> rows) =>
      _exportRows(rows).map((row) => row.map(_csvCell).join(',')).join('\n');

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  Future<void> _sendCsv(List<_PaymentRow> rows) => sendReportCsv(
    context: context,
    fileName: _fileName(extension: 'csv'),
    title: 'Customer Payments',
    csv: _csv(rows),
  );

  Future<void> _viewSendPdf(List<_PaymentRow> rows) => viewSendReportPdf(
    context: context,
    fileName: _fileName(extension: 'pdf'),
    title: 'Customer Payments',
    rows: _exportRows(rows),
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
