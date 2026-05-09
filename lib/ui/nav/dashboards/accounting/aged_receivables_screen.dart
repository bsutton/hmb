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
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/widgets.g.dart';
import 'report_csv_export.dart';

class AgedReceivablesScreen extends StatelessWidget {
  const AgedReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilderEx<AgedReceivablesReport>(
    future: AccountingReportService().agedReceivables(),
    waitingBuilder: (_) => const Center(child: CircularProgressIndicator()),
    builder: (context, report) {
      if (report == null) {
        return const Center(child: Text('No report data.'));
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Aged Receivables')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummary(context, report),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  HMBButton.withIcon(
                    label: 'Export CSV',
                    hint: 'Export aged receivables as a CSV file',
                    icon: const Icon(Icons.download),
                    onPressed: () async {
                      await exportCsv(
                        fileName: _exportFileName(report, 'csv'),
                        csv: AccountingReportCsvExporter().agedReceivables(
                          report,
                        ),
                      );
                    },
                  ),
                  HMBButton.withIcon(
                    label: 'Export PDF',
                    hint: 'Export aged receivables as a PDF file',
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: () async {
                      await exportReportPdf(
                        fileName: _exportFileName(report, 'pdf'),
                        title: 'Aged Receivables',
                        rows: _pdfRows(report),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (report.rows.isEmpty)
                const Surface(child: Text('No outstanding invoices.'))
              else
                for (final row in report.rows) _buildRow(context, row),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildSummary(BuildContext context, AgedReceivablesReport report) =>
      Surface(
        elevation: SurfaceElevation.e1,
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'As at ${formatLocalDate(report.asOfDate)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Total: ${report.total}'),
                Text('Current: ${report.buckets.current}'),
                Text('1-30: ${report.buckets.oneToThirty}'),
                Text('31-60: ${report.buckets.thirtyOneToSixty}'),
                Text('61-90: ${report.buckets.sixtyOneToNinety}'),
                Text('90+: ${report.buckets.overNinety}'),
              ],
            ),
          ],
        ),
      );

  Widget _buildRow(BuildContext context, AgedReceivablesRow row) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Surface(
      elevation: SurfaceElevation.e1,
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('Invoice #${row.invoiceId}'),
              Text('Due ${formatLocalDate(row.dueDate)}'),
              Text(_ageLabel(row.daysOverdue)),
              Text('Balance ${row.balance}'),
            ],
          ),
        ],
      ),
    ),
  );

  String _ageLabel(int daysOverdue) {
    if (daysOverdue <= 0) {
      return 'Current';
    }
    return '$daysOverdue day${daysOverdue == 1 ? '' : 's'} overdue';
  }

  List<List<String>> _pdfRows(AgedReceivablesReport report) => [
    ['Invoice', 'Customer', 'Due date', 'Days overdue', 'Balance'],
    for (final row in report.rows)
      [
        row.invoiceId.toString(),
        row.customerName,
        formatLocalDate(row.dueDate),
        row.daysOverdue.toString(),
        row.balance.toString(),
      ],
  ];

  String _exportFileName(AgedReceivablesReport report, String extension) =>
      accountingReportExportFileName(
        reportName: 'aged_receivables',
        extension: extension,
        asAt: report.asOfDate.toDateTime(),
      );
}
