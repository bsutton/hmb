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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:money2/money2.dart';

import '../../../../dao/dao.g.dart';
import '../../../../util/dart/format.dart';
import '../../../dialog/email_dialog.dart';
import '../../../widgets/icons/hmb_filter_icon.dart';
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/media/pdf_preview.dart';
import '../../../widgets/select/hmb_filter_sheet.dart';
import '../../../widgets/select/hmb_select_customer.dart';
import '../../../widgets/select/hmb_select_job.dart';
import '../../../widgets/widgets.g.dart' hide StatefulBuilder;
import 'accounting_period_selector.dart';
import 'debtor_statement_pdf.dart';
import 'report_csv_export.dart' as report_export;

class DebtorStatementScreen extends StatefulWidget {
  const DebtorStatementScreen({super.key});

  @override
  State<DebtorStatementScreen> createState() => _DebtorStatementScreenState();
}

class _DebtorStatementScreenState extends State<DebtorStatementScreen> {
  final _selectedCustomer = SelectedCustomer();
  final _selectedJob = SelectedJob();
  var _periodPreset = AccountingPeriodPreset.month;
  late DateTime _startInclusive;
  late DateTime _endExclusive;
  late DateTime _periodAnchor;
  late Future<DebtorStatementReport> _report;
  var _isLoadingReport = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startInclusive = DateTime(now.year, now.month);
    _endExclusive = DateTime(now.year, now.month + 1);
    _periodAnchor = _startInclusive;
    _reload();
  }

  void _reload() {
    final report = AccountingReportService().debtorStatement(
      customerId: _selectedCustomer.customerId,
      jobId: _selectedJob.jobId,
      startInclusive: _startInclusive,
      endExclusive: _endExclusive,
    );
    _report = report;
    _isLoadingReport = true;
    void markLoaded() {
      if (!mounted || !identical(_report, report)) {
        return;
      }
      setState(() => _isLoadingReport = false);
    }

    unawaited(
      report.then((_) => markLoaded(), onError: (_, _) => markLoaded()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customer Statement')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: HMBSelectCustomer(
                  selectedCustomer: _selectedCustomer,
                  onSelected: (_) => setState(_reload),
                  showAdd: false,
                ),
              ),
              HMBFilterIcon(
                active: _isFilterActive(),
                hint: 'Filter customer statement',
                onPressed: _showFilterSheet,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDateScroll(),
          const SizedBox(height: 12),
          if (_isLoadingReport)
            const Center(child: CircularProgressIndicator())
          else
            FutureBuilderEx<DebtorStatementReport>(
              future: _report,
              waitingBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              builder: (context, report) => report == null
                  ? const SizedBox.shrink()
                  : _buildReport(report),
            ),
        ],
      ),
    ),
  );

  Widget _buildDateScroll() => Surface(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous period',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _movePeriod(-1),
        ),
        Expanded(
          child: Text(
            _periodLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton(
          tooltip: 'Next period',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _movePeriod(1),
        ),
      ],
    ),
  );

  Future<void> _showFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HMBFilterSheet(
        contentBuilder: _buildFilterSheet,
        onReset: _resetFilters,
      ),
    );
  }

  Widget _buildFilterSheet(BuildContext context) => StatefulBuilder(
    builder: (context, setSheetState) => HMBColumn(
      children: [
        HMBSelectJob(
          selectedJob: _selectedJob,
          onSelected: (_) {
            setState(_reload);
            setSheetState(() {});
          },
        ),
        const SizedBox(height: 12),
        DropdownButton<AccountingPeriodPreset>(
          value: _periodPreset,
          isExpanded: true,
          items: [
            for (final preset in AccountingPeriodPreset.values)
              DropdownMenuItem(
                value: preset,
                child: Text(_presetLabel(preset)),
              ),
          ],
          onChanged: (value) async {
            if (value == null) {
              return;
            }
            _periodPreset = value;
            await _setPeriodForAnchor();
            setSheetState(() {});
          },
        ),
        if (_periodPreset == AccountingPeriodPreset.custom)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(formatDate(_startInclusive)),
                onPressed: () async {
                  await _pickStart(context);
                  setSheetState(() {});
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(formatDate(_lastDayFromDates())),
                onPressed: () async {
                  await _pickEnd(context);
                  setSheetState(() {});
                },
              ),
            ],
          ),
      ],
    ),
  );

  bool _isFilterActive() =>
      _selectedJob.jobId != null ||
      _periodPreset != AccountingPeriodPreset.month;

  void _resetFilters() {
    setState(() {
      _selectedJob.jobId = null;
      _periodPreset = AccountingPeriodPreset.month;
      final month = DateTime(_periodAnchor.year, _periodAnchor.month);
      _periodAnchor = month;
      _startInclusive = month;
      _endExclusive = DateTime(month.year, month.month + 1);
      _reload();
    });
  }

  Future<void> _movePeriod(int direction) async {
    _periodAnchor = switch (_periodPreset) {
      AccountingPeriodPreset.month => DateTime(
        _periodAnchor.year,
        _periodAnchor.month + direction,
      ),
      AccountingPeriodPreset.quarter => DateTime(
        _periodAnchor.year,
        _periodAnchor.month + (direction * 3),
      ),
      AccountingPeriodPreset.year || AccountingPeriodPreset.financialYear =>
        DateTime(_periodAnchor.year + direction, _periodAnchor.month),
      AccountingPeriodPreset.custom => _periodAnchor.add(
        Duration(days: direction),
      ),
    };
    await _setPeriodForAnchor();
  }

  Future<void> _setPeriodForAnchor() async {
    final next = switch (_periodPreset) {
      AccountingPeriodPreset.month => AccountingPeriod.forMonth(_periodAnchor),
      AccountingPeriodPreset.quarter => AccountingPeriod.forQuarter(
        _periodAnchor,
      ),
      AccountingPeriodPreset.year => AccountingPeriod.forYear(_periodAnchor),
      AccountingPeriodPreset.financialYear =>
        await AccountingPeriod.forFinancialYear(_periodAnchor),
      AccountingPeriodPreset.custom => AccountingPeriod(
        startInclusive: _startInclusive,
        endExclusive: _endExclusive,
      ),
    };
    _setPeriod(next);
  }

  Future<void> _pickStart(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startInclusive,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    _setPeriod(
      AccountingPeriod(
        startInclusive: selected,
        endExclusive: _endExclusive.isAfter(selected)
            ? _endExclusive
            : selected.add(const Duration(days: 1)),
      ),
    );
  }

  Future<void> _pickEnd(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _lastDayFromDates(),
      firstDate: _startInclusive,
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    _setPeriod(
      AccountingPeriod(
        startInclusive: _startInclusive,
        endExclusive: selected.add(const Duration(days: 1)),
      ),
    );
  }

  void _setPeriod(AccountingPeriod period) {
    setState(() {
      _startInclusive = period.startInclusive;
      _endExclusive = period.endExclusive;
      _periodAnchor = period.startInclusive;
      _reload();
    });
  }

  String get _periodLabel =>
      '${_formatPeriodDate(_startInclusive)} to '
      '${_formatPeriodDate(_lastDayFromDates())}';

  String _formatPeriodDate(DateTime date) {
    final now = DateTime.now();
    final includeYear =
        _startInclusive.year != now.year ||
        _lastDayFromDates().year != now.year;
    return formatDate(date, format: includeYear ? 'j M Y' : 'j M');
  }

  DateTime _lastDayFromDates() =>
      _endExclusive.subtract(const Duration(days: 1));

  String _presetLabel(AccountingPeriodPreset preset) => switch (preset) {
    AccountingPeriodPreset.month => 'Month',
    AccountingPeriodPreset.quarter => 'Quarter',
    AccountingPeriodPreset.year => 'Calendar year',
    AccountingPeriodPreset.financialYear => 'Financial year',
    AccountingPeriodPreset.custom => 'Custom',
  };

  Widget _buildReport(DebtorStatementReport report) => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Surface(
        elevation: SurfaceElevation.e1,
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.customerName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Opening: ${report.openingBalance}'),
                Text('Closing: ${report.closingBalance}'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                HMBButton.withIcon(
                  label: 'Send CSV',
                  hint: 'Email this customer statement as a CSV file',
                  icon: const Icon(Icons.email),
                  onPressed: () async {
                    await _sendStatementCsv(report);
                  },
                ),
                HMBButton.withIcon(
                  label: 'View/Send PDF',
                  hint: report.customerId == null
                      ? 'Select a customer before creating a statement PDF'
                      : 'View and optionally email this customer statement',
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () => _viewSendStatement(report),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (report.entries.isEmpty)
        const Surface(child: Text('No statement activity for this period.'))
      else
        Surface(
          child: HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in _statementRows(report))
                _buildStatementRow(report, row),
            ],
          ),
        ),
    ],
  );

  Future<void> _sendStatementCsv(DebtorStatementReport report) async {
    final emails = await _statementEmails(report);
    if (!mounted) {
      return;
    }
    await report_export.sendReportCsv(
      context: context,
      fileName: _exportFileName(report, 'csv'),
      csv: AccountingReportCsvExporter().debtorStatement(report),
      title: 'Customer Statement',
      preferredRecipient: emails.firstOrNull ?? '',
      emailRecipients: emails,
      emailBody:
          '''
Please find attached your customer statement CSV.

Period: ${formatDate(report.startInclusive)} to ${formatDate(_lastDay(report))}
Closing balance: ${report.closingBalance}
''',
    );
  }

  DateTime _lastDay(DebtorStatementReport report) =>
      report.endExclusive.subtract(const Duration(days: 1));

  String _exportFileName(DebtorStatementReport report, String extension) =>
      report_export.accountingReportExportFileName(
        reportName: 'customer_statement',
        extension: extension,
        entityName: report.customerName,
        entityId: report.customerId,
        startInclusive: report.startInclusive,
        endInclusive: _lastDay(report),
      );

  Future<void> _viewSendStatement(DebtorStatementReport report) async {
    if (report.customerId == null) {
      HMBToast.error(
        'Select a customer before creating a customer statement PDF.',
      );
      return;
    }
    final file = await buildDebtorStatementPdfFile(
      fileName: _exportFileName(report, 'pdf'),
      report: report,
    );
    final emails = await _statementEmails(report);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PdfPreviewScreen(
          title: 'Customer Statement',
          filePath: file.path,
          preferredRecipient: emails.firstOrNull ?? '',
          emailSubject: 'Customer Statement',
          emailBody:
              '''
Please find attached your customer statement.

Period: ${formatDate(report.startInclusive)} to ${formatDate(_lastDay(report))}
Closing balance: ${report.closingBalance}
''',
          sendEmailDialog:
              ({
                required preferredRecipient,
                required subject,
                required body,
                required attachmentPaths,
              }) => EmailDialog(
                preferredRecipient: preferredRecipient,
                subject: subject,
                body: body,
                attachmentPaths: attachmentPaths,
                emailRecipients: [...emails],
              ),
          canEmail: () async => EmailBlocked(
            blocked: emails.isEmpty,
            reason: 'there is no customer email address',
          ),
          onSent: () async {},
        ),
      ),
    );
  }

  Future<List<String>> _statementEmails(DebtorStatementReport report) async {
    final customerId = report.customerId;
    if (customerId == null) {
      return const [];
    }
    final contacts = await DaoContact().getByCustomer(customerId);
    return contacts
        .map((contact) => contact.bestEmail)
        .nonNulls
        .where((email) => email.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  Widget _buildStatementRow(DebtorStatementReport report, _StatementRow row) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _statementRowColor(row),
                fontWeight: FontWeight.w600,
              ),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (row.date != null) Text(formatDate(row.date!)),
                if (row.invoiceNumber != null)
                  Text('Invoice #${row.invoiceNumber}'),
                if (report.customerId == null && row.customerName != null)
                  Text(row.customerName!),
                if (row.amount != null) Text(row.amount.toString()),
                Text('Balance: ${row.balance}'),
              ],
            ),
          ],
        ),
      );

  List<_StatementRow> _statementRows(DebtorStatementReport report) {
    var balance = report.openingBalance;
    final rows = <_StatementRow>[];
    for (final entry in report.entries) {
      balance += entry.amount;
      rows.add(_StatementRow.entry(entry, balance));
    }
    return rows;
  }

  Color _statementRowColor(_StatementRow row) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (row.type) {
      DebtorStatementEntryType.invoice => colorScheme.primary,
      DebtorStatementEntryType.payment ||
      DebtorStatementEntryType.credit => Colors.green.shade700,
      DebtorStatementEntryType.adjustment => Colors.orange.shade800,
    };
  }
}

class _StatementRow {
  final DebtorStatementEntryType type;
  final DateTime? date;
  final String? invoiceNumber;
  final String? customerName;
  final String description;
  final Money? amount;
  final Money balance;

  const _StatementRow({
    required this.type,
    required this.date,
    required this.invoiceNumber,
    required this.customerName,
    required this.description,
    required this.amount,
    required this.balance,
  });

  factory _StatementRow.entry(DebtorStatementEntry entry, Money balance) =>
      _StatementRow(
        type: entry.type,
        date: entry.date,
        invoiceNumber: entry.invoiceNumber,
        customerName: entry.customerName,
        description: entry.description,
        amount: entry.amount,
        balance: balance,
      );
}
