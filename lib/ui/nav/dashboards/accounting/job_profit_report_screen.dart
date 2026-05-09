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
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/select/hmb_select_job.dart';
import '../../../widgets/widgets.g.dart';
import 'report_csv_export.dart';

class JobProfitReportScreen extends StatefulWidget {
  const JobProfitReportScreen({super.key});

  @override
  State<JobProfitReportScreen> createState() => _JobProfitReportScreenState();
}

class _JobProfitReportScreenState extends State<JobProfitReportScreen> {
  final _selectedJob = SelectedJob();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Job Profit')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HMBSelectJob(
            selectedJob: _selectedJob,
            onSelected: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (_selectedJob.jobId == null)
            const Surface(child: Text('Select a job to view profit.'))
          else
            FutureBuilderEx<JobProfitReport>(
              future: AccountingReportService().jobProfit(_selectedJob.jobId!),
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

  Widget _buildReport(JobProfitReport report) => Surface(
    elevation: SurfaceElevation.e1,
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            HMBButton.withIcon(
              label: 'Export CSV',
              hint: 'Export job profit as a CSV file',
              icon: const Icon(Icons.download),
              onPressed: () async {
                final job = await DaoJob().getById(report.jobId);
                await exportCsv(
                  fileName: _exportFileName(
                    report,
                    'csv',
                    jobName: job?.summary,
                  ),
                  csv: AccountingReportCsvExporter().jobProfit(report),
                );
              },
            ),
            HMBButton.withIcon(
              label: 'Export PDF',
              hint: 'Export job profit as a PDF file',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                final job = await DaoJob().getById(report.jobId);
                await exportReportPdf(
                  fileName: _exportFileName(
                    report,
                    'pdf',
                    jobName: job?.summary,
                  ),
                  title: 'Job Profit',
                  rows: _pdfRows(report),
                );
              },
            ),
          ],
        ),
        const Divider(),
        _row('Invoice income', report.invoiceIncome.toString()),
        _row('Credits', '-${report.creditNotes}'),
        _row('Adjustments', '-${report.debtorAdjustments}'),
        _row('Net income', report.netIncome.toString(), bold: true),
        const Divider(),
        _row('Supplier receipts', '-${report.receiptExpenses}'),
        _row('Unreceipted actual costs', '-${report.unreceiptedActualCosts}'),
        _row('Net profit', report.netProfit.toString(), bold: true),
      ],
    ),
  );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ),
        Text(
          value,
          style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
      ],
    ),
  );

  List<List<String>> _pdfRows(JobProfitReport report) => [
    ['Line', 'Amount'],
    ['Invoice income', report.invoiceIncome.toString()],
    ['Credits', '-${report.creditNotes}'],
    ['Adjustments', '-${report.debtorAdjustments}'],
    ['Net income', report.netIncome.toString()],
    ['Supplier receipts', '-${report.receiptExpenses}'],
    ['Unreceipted actual costs', '-${report.unreceiptedActualCosts}'],
    ['Net profit', report.netProfit.toString()],
  ];

  String _exportFileName(
    JobProfitReport report,
    String extension, {
    String? jobName,
  }) => accountingReportExportFileName(
    reportName: 'job_profit',
    extension: extension,
    entityName: jobName,
    entityId: report.jobId,
  );
}
