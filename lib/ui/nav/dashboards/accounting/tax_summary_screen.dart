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

class TaxSummaryScreen extends StatefulWidget {
  const TaxSummaryScreen({super.key});

  @override
  State<TaxSummaryScreen> createState() => _TaxSummaryScreenState();
}

class _TaxSummaryScreenState extends State<TaxSummaryScreen> {
  late AccountingPeriod _period;
  late Future<TaxSummaryReport> _report;

  @override
  void initState() {
    super.initState();
    _period = AccountingPeriod.forMonth(DateTime.now());
    _reload();
  }

  void _reload() {
    _report = AccountingReportService().taxSummary(_period);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tax Summary')),
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
          FutureBuilderEx<TaxSummaryReport>(
            future: _report,
            waitingBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            builder: (context, report) {
              if (report == null) {
                return const Center(child: Text('No report data.'));
              }
              return Surface(
                elevation: SurfaceElevation.e1,
                child: HMBColumn(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        HMBButton.withIcon(
                          label: 'Send CSV',
                          hint: 'Email tax summary as a CSV file',
                          icon: const Icon(Icons.email),
                          onPressed: () async {
                            await sendReportCsv(
                              context: context,
                              fileName: _exportFileName(report, 'csv'),
                              title: '${report.taxLabel} Summary',
                              csv: AccountingReportCsvExporter().taxSummary(
                                report,
                              ),
                            );
                          },
                        ),
                        HMBButton.withIcon(
                          label: 'View/Send PDF',
                          hint:
                              'View and optionally email tax summary as a PDF',
                          icon: const Icon(Icons.picture_as_pdf),
                          onPressed: () async {
                            await viewSendReportPdf(
                              context: context,
                              fileName: _exportFileName(report, 'pdf'),
                              title: '${report.taxLabel} Summary',
                              rows: _pdfRows(report),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    _line(
                      '${report.taxLabel} collected from invoices',
                      report.taxCollected.toString(),
                    ),
                    _line(
                      '${report.taxLabel} credited',
                      '-${report.creditTax}',
                    ),
                    _line(
                      'Net ${report.taxLabel} collected',
                      report.netTaxCollected.toString(),
                      bold: true,
                    ),
                    const Divider(),
                    _line(
                      '${report.taxLabel} paid on receipts',
                      '-${report.supplierTaxPaid}',
                    ),
                    _line(
                      'Net ${report.taxLabel} position',
                      report.netTaxPosition.toString(),
                      bold: true,
                    ),
                    if (report.taxCollectedIsEstimated) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Invoice ${report.taxLabel} is derived from inclusive '
                        'invoice totals and the configured tax rate.',
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _line(String label, String value, {bool bold = false}) => Padding(
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

  List<List<String>> _pdfRows(TaxSummaryReport report) => [
    ['Line', 'Amount'],
    [
      '${report.taxLabel} collected from invoices',
      report.taxCollected.toString(),
    ],
    ['${report.taxLabel} credited', '-${report.creditTax}'],
    ['Net ${report.taxLabel} collected', report.netTaxCollected.toString()],
    ['${report.taxLabel} paid on receipts', '-${report.supplierTaxPaid}'],
    ['Net ${report.taxLabel} position', report.netTaxPosition.toString()],
  ];

  String _exportFileName(TaxSummaryReport report, String extension) =>
      accountingReportExportFileName(
        reportName: '${report.taxLabel}_summary',
        extension: extension,
        startInclusive: report.period.startInclusive,
        endInclusive: report.period.endExclusive.subtract(
          const Duration(days: 1),
        ),
      );
}
