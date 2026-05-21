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

import '../../../../dao/dao.g.dart';
import '../../../../util/dart/format.dart';
import '../../../dialog/email_dialog.dart';
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/media/pdf_preview.dart';
import '../../../widgets/select/hmb_select_customer.dart';
import '../../../widgets/select/hmb_select_job.dart';
import '../../../widgets/widgets.g.dart';
import 'accounting_period_selector.dart';
import 'report_csv_export.dart';

class DebtorStatementScreen extends StatefulWidget {
  const DebtorStatementScreen({super.key});

  @override
  State<DebtorStatementScreen> createState() => _DebtorStatementScreenState();
}

class _DebtorStatementScreenState extends State<DebtorStatementScreen> {
  final _selectedCustomer = SelectedCustomer();
  final _selectedJob = SelectedJob();
  late DateTime _startInclusive;
  late DateTime _endExclusive;
  late Future<DebtorStatementReport> _report;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startInclusive = DateTime(now.year, now.month);
    _endExclusive = DateTime(now.year, now.month + 1);
    _reload();
  }

  void _reload() {
    _report = AccountingReportService().debtorStatement(
      customerId: _selectedCustomer.customerId,
      jobId: _selectedJob.jobId,
      startInclusive: _startInclusive,
      endExclusive: _endExclusive,
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
          HMBSelectCustomer(
            selectedCustomer: _selectedCustomer,
            onSelected: (_) => setState(_reload),
          ),
          const SizedBox(height: 12),
          HMBSelectJob(
            selectedJob: _selectedJob,
            onSelected: (_) => setState(_reload),
          ),
          const SizedBox(height: 12),
          AccountingPeriodSelector(
            initialPeriod: AccountingPeriod(
              startInclusive: _startInclusive,
              endExclusive: _endExclusive,
            ),
            onChanged: (period) => setState(() {
              _startInclusive = period.startInclusive;
              _endExclusive = period.endExclusive;
              _reload();
            }),
          ),
          const SizedBox(height: 12),
          FutureBuilderEx<DebtorStatementReport>(
            future: _report,
            waitingBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            builder: (context, report) =>
                report == null ? const SizedBox.shrink() : _buildReport(report),
          ),
        ],
      ),
    ),
  );

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
            Text(
              '${formatDate(report.startInclusive)} to '
              '${formatDate(_lastDay(report))}',
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
                  hint: 'View and optionally email this customer statement',
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
        for (final entry in report.entries) _buildEntry(entry),
    ],
  );

  Future<void> _sendStatementCsv(DebtorStatementReport report) async {
    final emails = await _statementEmails(report);
    if (!mounted) {
      return;
    }
    await sendReportCsv(
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
      accountingReportExportFileName(
        reportName: 'customer_statement',
        extension: extension,
        entityName: report.customerName,
        entityId: report.customerId,
        startInclusive: report.startInclusive,
        endInclusive: _lastDay(report),
      );

  Future<void> _viewSendStatement(DebtorStatementReport report) async {
    final file = await buildDebtorStatementPdfFile(
      fileName: _exportFileName(report, 'pdf'),
      title: 'Customer Statement',
      customerName: report.customerName,
      period:
          '${formatDate(report.startInclusive)} to '
          '${formatDate(_lastDay(report))}',
      openingBalance: report.openingBalance.toString(),
      closingBalance: report.closingBalance.toString(),
      rows: _statementPdfRows(report),
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

  Widget _buildEntry(DebtorStatementEntry entry) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Surface(
      elevation: SurfaceElevation.e1,
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(formatDate(entry.date)),
              Text('Invoice #${entry.invoiceNumber}'),
              Text(entry.amount.toString()),
            ],
          ),
        ],
      ),
    ),
  );

  List<DebtorStatementPdfRow> _statementPdfRows(DebtorStatementReport report) =>
      [
        for (final entry in report.entries)
          DebtorStatementPdfRow(
            date: formatDate(entry.date),
            invoiceNumber: entry.invoiceNumber,
            description: entry.description,
            amount: entry.amount.toString(),
          ),
      ];
}
