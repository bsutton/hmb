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
import '../../../widgets/widgets.g.dart';
import 'accounting_period_selector.dart';
import 'report_csv_export.dart';

class SupplierSpendScreen extends StatefulWidget {
  const SupplierSpendScreen({super.key});

  @override
  State<SupplierSpendScreen> createState() => _SupplierSpendScreenState();
}

class _SupplierSpendScreenState extends State<SupplierSpendScreen> {
  late AccountingPeriod _period;
  late Future<SupplierSpendReport> _report;

  @override
  void initState() {
    super.initState();
    _period = AccountingPeriod.forMonth(DateTime.now());
    _reload();
  }

  void _reload() {
    _report = AccountingReportService().supplierSpend(_period);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Supplier Spend')),
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
          FutureBuilderEx<SupplierSpendReport>(
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
                    const Surface(child: Text('No supplier receipts.'))
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

  Widget _summary(BuildContext context, SupplierSpendReport report) => Surface(
    elevation: SurfaceElevation.e1,
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selected period', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('Excluding tax: ${report.totalExcludingTax}'),
            Text('Tax: ${report.totalTax}'),
            Text('Including tax: ${report.totalIncludingTax}'),
          ],
        ),
      ],
    ),
  );

  Widget _actions(SupplierSpendReport report) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      HMBButton.withIcon(
        label: 'Export CSV',
        hint: 'Export supplier spend as a CSV file',
        icon: const Icon(Icons.download),
        onPressed: () async {
          await exportCsv(
            fileName: 'supplier_spend.csv',
            csv: AccountingReportCsvExporter().supplierSpend(report),
          );
        },
      ),
      HMBButton.withIcon(
        label: 'Export PDF',
        hint: 'Export supplier spend as a PDF file',
        icon: const Icon(Icons.picture_as_pdf),
        onPressed: () async {
          await exportReportPdf(
            fileName: 'supplier_spend.pdf',
            title: 'Supplier Spend',
            rows: _pdfRows(report),
          );
        },
      ),
    ],
  );

  Widget _row(BuildContext context, SupplierSpendRow row) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Surface(
      elevation: SurfaceElevation.e1,
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.supplierName, style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('${row.receiptCount} receipts'),
              Text('Ex tax ${row.excludingTax}'),
              Text('Tax ${row.tax}'),
              Text('Total ${row.includingTax}'),
            ],
          ),
        ],
      ),
    ),
  );

  List<List<String>> _pdfRows(SupplierSpendReport report) => [
    ['Supplier', 'Receipts', 'Excluding tax', 'Tax', 'Including tax'],
    for (final row in report.rows)
      [
        row.supplierName,
        row.receiptCount.toString(),
        row.excludingTax.toString(),
        row.tax.toString(),
        row.includingTax.toString(),
      ],
  ];
}
