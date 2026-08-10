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

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../../dao/dao.g.dart';
import '../../../../util/dart/format.dart';
import '../../../../util/dart/local_date.dart';
import '../../../../util/dart/money_ex.dart';
import '../../../dialog/email_dialog.dart';
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/widgets.g.dart';
import 'accounting_period_selector.dart';
import 'report_csv_export.dart';

class AccountantTaxPackScreen extends StatefulWidget {
  const AccountantTaxPackScreen({super.key});

  @override
  State<AccountantTaxPackScreen> createState() =>
      _AccountantTaxPackScreenState();
}

class _AccountantTaxPackScreenState extends State<AccountantTaxPackScreen> {
  late Future<AccountingPeriod> _initialPeriod;
  AccountingPeriod? _period;
  var _building = false;

  @override
  void initState() {
    super.initState();
    _initialPeriod = AccountingPeriod.forFinancialYear(DateTime.now());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Accountant Tax Pack')),
    body: FutureBuilderEx<AccountingPeriod>(
      future: _initialPeriod,
      waitingBuilder: (_) => const Center(child: CircularProgressIndicator()),
      builder: (context, initialPeriod) {
        if (initialPeriod == null) {
          return const Center(child: Text('No report period available.'));
        }
        _period ??= initialPeriod;
        final period = _period!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccountingPeriodSelector(
                initialPeriod: period,
                onChanged: (period) => setState(() => _period = period),
              ),
              Surface(
                elevation: SurfaceElevation.e1,
                child: HMBColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _periodLabel(period),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'Creates one Excel workbook for your accountant.',
                    ),
                    const Text('Included sheets:'),
                    const Text('Profit and loss'),
                    const Text('Tax summary'),
                    const Text('Customer payments'),
                    const Text('Receipt details'),
                    const Text('Supplier spend'),
                    const Text('Debtor statement activity'),
                    const Text('Aged receivables as at period end'),
                    const Text('Unlinked costs'),
                    HMBButton.withIcon(
                      label: _building ? 'Preparing...' : 'Send Tax Pack',
                      hint: 'Prepare and email the accountant tax report pack',
                      icon: _building
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.email),
                      enabled: !_building,
                      onPressed: () => _sendTaxPack(period),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _sendTaxPack(AccountingPeriod period) async {
    setState(() => _building = true);
    try {
      final file = await _buildWorkbook(period);
      if (!mounted) {
        return;
      }
      await showDialog<bool>(
        context: context,
        builder: (context) => EmailDialog(
          preferredRecipient: '',
          subject: 'Accountant tax pack ${_periodLabel(period)}',
          body:
              'Please find attached the accountant tax pack for '
              '${_periodLabel(period)}.',
          attachmentPaths: [file.path],
          emailRecipients: const <String>[],
        ),
      );
    } catch (e) {
      HMBToast.error(
        'Failed to prepare accountant tax pack: $e',
        acknowledgmentRequired: true,
      );
    } finally {
      if (mounted) {
        setState(() => _building = false);
      }
    }
  }

  Future<File> _buildWorkbook(AccountingPeriod period) async {
    final service = AccountingReportService();
    final endInclusive = period.endExclusive.subtract(const Duration(days: 1));

    final profitAndLoss = await service.profitAndLoss(period);
    final taxSummary = await service.taxSummary(period);
    final cashReceived = await service.cashReceived(period);
    final receiptDetails = await _receiptDetails(period);
    final supplierSpend = await service.supplierSpend(period);
    final debtorStatement = await service.debtorStatement(
      customerId: null,
      startInclusive: period.startInclusive,
      endExclusive: period.endExclusive,
    );
    final agedReceivables = await service.agedReceivables(
      asOfDate: LocalDate.fromDateTime(endInclusive),
    );
    final unlinkedCosts = await service.unlinkedCosts();

    final workbook = _Workbook([
      _Sheet('Profit and Loss', _profitAndLossRows(profitAndLoss)),
      _Sheet('Tax Summary', _taxSummaryRows(taxSummary)),
      _Sheet('Customer Payments', _cashReceivedRows(cashReceived)),
      _Sheet('Receipts', receiptDetails),
      _Sheet('Supplier Spend', _supplierSpendRows(supplierSpend)),
      _Sheet('Debtor Activity', _debtorStatementRows(debtorStatement)),
      _Sheet('Aged Receivables', _agedReceivablesRows(agedReceivables)),
      _Sheet('Unlinked Costs', _unlinkedCostRows(unlinkedCosts)),
    ]);
    final dir = await Directory.systemTemp.createTemp('hmb_tax_pack_');
    final file = File(
      '${dir.path}/${accountingReportExportFileName(reportName: 'accountant_tax_pack', extension: 'xlsx', startInclusive: period.startInclusive, endInclusive: endInclusive)}',
    );
    await file.writeAsBytes(_buildXlsx(workbook), flush: true);
    return file;
  }

  List<List<Object?>> _profitAndLossRows(ProfitAndLossReport report) => [
    ['Line', 'Amount'],
    ['Invoice income', report.invoiceIncome],
    ['Credits', -report.creditNotes],
    ['Adjustments', -report.debtorAdjustments],
    ['Net income', report.netIncome],
    ['Supplier receipts', -report.receiptExpenses],
    ['Net profit', report.netProfit],
  ];

  List<List<Object?>> _taxSummaryRows(TaxSummaryReport report) => [
    ['Line', 'Amount'],
    ['${report.taxLabel} collected from invoices', report.taxCollected],
    ['${report.taxLabel} credited', -report.creditTax],
    ['Net ${report.taxLabel} collected', report.netTaxCollected],
    ['${report.taxLabel} paid on receipts', -report.supplierTaxPaid],
    ['Net ${report.taxLabel} position', report.netTaxPosition],
    if (report.taxCollectedIsEstimated)
      ['Invoice ${report.taxLabel} values estimated', 'Yes'],
    if (!report.taxCollectedIsEstimated)
      ['Invoice ${report.taxLabel} values estimated', 'No'],
  ];

  List<List<Object?>> _cashReceivedRows(CashReceivedReport report) => [
    ['Date', 'Payment', 'Invoice', 'Customer', 'Method', 'Reference', 'Amount'],
    for (final row in report.rows)
      [
        row.paymentDate,
        row.paymentId,
        row.invoiceId,
        row.customerName,
        row.paymentMethod,
        row.reference,
        row.amount,
      ],
  ];

  Future<List<List<Object?>>> _receiptDetails(AccountingPeriod period) async {
    final db = DaoReceipt().withoutTransaction();
    final rows = await db.rawQuery(
      '''
SELECT
  r.id,
  r.receipt_date,
  IFNULL(s.name, 'No supplier') AS supplier_name,
  j.summary AS job_summary,
  r.total_excluding_tax,
  r.tax,
  r.total_including_tax
FROM receipt r
LEFT JOIN supplier s ON s.id = r.supplier_id
LEFT JOIN job j ON j.id = r.job_id
WHERE r.receipt_date >= ? AND r.receipt_date < ?
ORDER BY r.receipt_date ASC, r.id ASC
''',
      [
        period.startInclusive.toIso8601String(),
        period.endExclusive.toIso8601String(),
      ],
    );
    return [
      [
        'Receipt',
        'Date',
        'Supplier',
        'Job',
        'Excluding tax',
        'Tax',
        'Including tax',
      ],
      for (final row in rows)
        [
          row['id'],
          DateTime.parse(row['receipt_date']! as String),
          row['supplier_name'],
          row['job_summary'],
          MoneyEx.fromInt(row['total_excluding_tax'] as int? ?? 0),
          MoneyEx.fromInt(row['tax'] as int? ?? 0),
          MoneyEx.fromInt(row['total_including_tax'] as int? ?? 0),
        ],
    ];
  }

  List<List<Object?>> _supplierSpendRows(SupplierSpendReport report) => [
    ['Supplier', 'Receipts', 'Excluding tax', 'Tax', 'Including tax'],
    for (final row in report.rows)
      [
        row.supplierName,
        row.receiptCount,
        row.excludingTax,
        row.tax,
        row.includingTax,
      ],
  ];

  List<List<Object?>> _debtorStatementRows(DebtorStatementReport report) {
    var balance = report.openingBalance;
    final rows = <List<Object?>>[
      ['Date', 'Invoice', 'Customer', 'Description', 'Amount', 'Balance'],
      ['', '', '', 'Opening balance', '', balance],
    ];
    for (final entry in report.entries) {
      balance += entry.amount;
      rows.add([
        entry.date,
        entry.invoiceNumber,
        entry.customerName,
        entry.description,
        entry.amount,
        balance,
      ]);
    }
    rows.add(['', '', '', 'Closing balance', '', balance]);
    return rows;
  }

  List<List<Object?>> _agedReceivablesRows(AgedReceivablesReport report) => [
    ['Invoice', 'Customer', 'Due date', 'Days overdue', 'Balance'],
    for (final row in report.rows)
      [
        row.invoiceId,
        row.customerName,
        row.dueDate.toDateTime(),
        row.daysOverdue,
        row.balance,
      ],
  ];

  List<List<Object?>> _unlinkedCostRows(UnlinkedCostReport report) => [
    ['Receipt', 'Date', 'Supplier', 'Job', 'Amount'],
    for (final row in report.rows)
      [
        row.receiptId,
        row.receiptDate,
        row.supplierName,
        row.jobSummary,
        row.amount,
      ],
  ];

  String _periodLabel(AccountingPeriod period) {
    final endInclusive = period.endExclusive.subtract(const Duration(days: 1));
    return '${formatDate(period.startInclusive, format: 'j M Y')} to '
        '${formatDate(endInclusive, format: 'j M Y')}';
  }
}

class _Workbook {
  final List<_Sheet> sheets;

  const _Workbook(this.sheets);
}

class _Sheet {
  final String name;
  final List<List<Object?>> rows;

  const _Sheet(this.name, this.rows);
}

List<int> _buildXlsx(_Workbook workbook) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string('[Content_Types].xml', _contentTypes(workbook)),
    )
    ..addFile(ArchiveFile.string('_rels/.rels', _rootRelationships()))
    ..addFile(ArchiveFile.string('xl/workbook.xml', _workbookXml(workbook)))
    ..addFile(
      ArchiveFile.string(
        'xl/_rels/workbook.xml.rels',
        _workbookRelationships(workbook),
      ),
    )
    ..addFile(ArchiveFile.string('xl/styles.xml', _stylesXml()));
  for (var i = 0; i < workbook.sheets.length; i++) {
    archive.addFile(
      ArchiveFile.string(
        'xl/worksheets/sheet${i + 1}.xml',
        _sheetXml(workbook.sheets[i]),
      ),
    );
  }
  return ZipEncoder().encodeBytes(archive);
}

String _contentTypes(_Workbook workbook) =>
    '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  ${[for (var i = 0; i < workbook.sheets.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join('\n  ')}
</Types>
''';

String _rootRelationships() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
''';

String _workbookXml(_Workbook workbook) =>
    '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    ${[for (var i = 0; i < workbook.sheets.length; i++) '<sheet name="${_xml(workbook.sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join('\n    ')}
  </sheets>
</workbook>
''';

String _workbookRelationships(_Workbook workbook) =>
    '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  ${[for (var i = 0; i < workbook.sheets.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join('\n  ')}
  <Relationship Id="rId${workbook.sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
''';

String _stylesXml() => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2"><font/><font><b/></font></fonts>
  <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
  <borders count="1"><border/></borders>
  <cellStyleXfs count="1"><xf/></cellStyleXfs>
  <cellXfs count="2"><xf fontId="0"/><xf fontId="1" applyFont="1"/></cellXfs>
</styleSheet>
''';

String _sheetXml(_Sheet sheet) {
  final rows = <String>[];
  for (var rowIndex = 0; rowIndex < sheet.rows.length; rowIndex++) {
    final cells = sheet.rows[rowIndex];
    rows.add(
      '<row r="${rowIndex + 1}">${[for (var colIndex = 0; colIndex < cells.length; colIndex++) _cell(cells[colIndex], rowIndex + 1, colIndex + 1, rowIndex == 0)].join()}</row>',
    );
  }
  return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    ${rows.join('\n    ')}
  </sheetData>
</worksheet>
''';
}

String _cell(Object? value, int row, int col, bool heading) {
  final ref = '${_columnName(col)}$row';
  final style = heading ? ' s="1"' : '';
  if (value == null) {
    return '<c r="$ref"$style/>';
  }
  if (value is num) {
    return '<c r="$ref"$style><v>$value</v></c>';
  }
  return '<c r="$ref" t="inlineStr"$style><is><t>${_xml(_cellText(value))}</t></is></c>';
}

String _cellText(Object value) {
  if (value is DateTime) {
    return formatDate(value, format: 'Y-m-d');
  }
  return value.toString();
}

String _columnName(int col) {
  var value = col;
  final chars = <String>[];
  while (value > 0) {
    value--;
    chars.insert(0, String.fromCharCode(65 + (value % 26)));
    value ~/= 26;
  }
  return chars.join();
}

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
