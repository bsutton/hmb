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
import 'accounting_period_selector.dart';
import 'report_csv_export.dart';

class CashReceivedScreen extends StatefulWidget {
  const CashReceivedScreen({super.key});

  @override
  State<CashReceivedScreen> createState() => _CashReceivedScreenState();
}

class _CashReceivedScreenState extends State<CashReceivedScreen> {
  late AccountingPeriod _period;
  late Future<CashReceivedReport> _report;

  @override
  void initState() {
    super.initState();
    _period = AccountingPeriod.forMonth(DateTime.now());
    _reload();
  }

  void _reload() {
    _report = AccountingReportService().cashReceived(_period);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cash Received')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountingPeriodSelector(
            initialPeriod: _period,
            onChanged: (period) => setState(() {
              _period = period;
              _reload();
            }),
          ),
          const SizedBox(height: 12),
          FutureBuilderEx<CashReceivedReport>(
            future: _report,
            waitingBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            builder: (context, report) {
              if (report == null) {
                return const Center(child: Text('No report data.'));
              }
              return HMBColumn(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summary(context, report),
                  const SizedBox(height: 12),
                  _actions(report),
                  const SizedBox(height: 12),
                  if (report.rows.isEmpty)
                    const Surface(child: Text('No customer payments.'))
                  else
                    for (final row in report.rows) _row(context, row),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _summary(BuildContext context, CashReceivedReport report) => Surface(
    elevation: SurfaceElevation.e1,
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selected period', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Total received: ${report.total}'),
      ],
    ),
  );

  Widget _actions(CashReceivedReport report) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      HMBButton.withIcon(
        label: 'Export CSV',
        hint: 'Export cash received as a CSV file',
        icon: const Icon(Icons.download),
        onPressed: () async {
          await exportCsv(
            fileName: 'cash_received.csv',
            csv: AccountingReportCsvExporter().cashReceived(report),
          );
        },
      ),
      HMBButton.withIcon(
        label: 'Export PDF',
        hint: 'Export cash received as a PDF file',
        icon: const Icon(Icons.picture_as_pdf),
        onPressed: () async {
          await exportReportPdf(
            fileName: 'cash_received.pdf',
            title: 'Cash Received',
            rows: _pdfRows(report),
          );
        },
      ),
    ],
  );

  Widget _row(BuildContext context, CashReceivedRow row) => Padding(
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
              Text(formatDate(row.paymentDate)),
              if (row.invoiceId != null) Text('Invoice #${row.invoiceId}'),
              if (row.paymentMethod != null) Text(row.paymentMethod!),
              if (row.reference != null) Text(row.reference!),
              Text(row.amount.toString()),
            ],
          ),
        ],
      ),
    ),
  );

  List<List<String>> _pdfRows(CashReceivedReport report) => [
    ['Date', 'Invoice', 'Customer', 'Method', 'Reference', 'Amount'],
    for (final row in report.rows)
      [
        formatDate(row.paymentDate),
        row.invoiceId?.toString() ?? '',
        row.customerName,
        row.paymentMethod ?? '',
        row.reference ?? '',
        row.amount.toString(),
      ],
  ];
}
