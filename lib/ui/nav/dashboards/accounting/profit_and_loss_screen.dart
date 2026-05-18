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

class ProfitAndLossScreen extends StatefulWidget {
  const ProfitAndLossScreen({super.key});

  @override
  State<ProfitAndLossScreen> createState() => _ProfitAndLossScreenState();
}

class _ProfitAndLossScreenState extends State<ProfitAndLossScreen> {
  late AccountingPeriod _period;
  late Future<ProfitAndLossReport> _report;

  @override
  void initState() {
    super.initState();
    _period = AccountingPeriod.forMonth(DateTime.now());
    _reload();
  }

  void _reload() {
    _report = AccountingReportService().profitAndLoss(_period);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profit and Loss')),
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
          FutureBuilderEx<ProfitAndLossReport>(
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
                          hint: 'Email profit and loss as a CSV file',
                          icon: const Icon(Icons.email),
                          onPressed: () async {
                            await sendReportCsv(
                              context: context,
                              fileName: _exportFileName('csv'),
                              title: 'Profit and Loss',
                              csv: AccountingReportCsvExporter().profitAndLoss(
                                report,
                              ),
                            );
                          },
                        ),
                        HMBButton.withIcon(
                          label: 'View/Send PDF',
                          hint:
                              'View and optionally email profit and loss '
                              'as a PDF',
                          icon: const Icon(Icons.picture_as_pdf),
                          onPressed: () async {
                            await viewSendReportPdf(
                              context: context,
                              fileName: _exportFileName('pdf'),
                              title: 'Profit and Loss',
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
                    _row('Net profit', report.netProfit.toString(), bold: true),
                  ],
                ),
              );
            },
          ),
        ],
      ),
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

  List<List<String>> _pdfRows(ProfitAndLossReport report) => [
    ['Line', 'Amount'],
    ['Invoice income', report.invoiceIncome.toString()],
    ['Credits', '-${report.creditNotes}'],
    ['Adjustments', '-${report.debtorAdjustments}'],
    ['Net income', report.netIncome.toString()],
    ['Supplier receipts', '-${report.receiptExpenses}'],
    ['Net profit', report.netProfit.toString()],
  ];

  String _exportFileName(String extension) => accountingReportExportFileName(
    reportName: 'profit_and_loss',
    extension: extension,
    startInclusive: _period.startInclusive,
    endInclusive: _period.endExclusive.subtract(const Duration(days: 1)),
  );
}
