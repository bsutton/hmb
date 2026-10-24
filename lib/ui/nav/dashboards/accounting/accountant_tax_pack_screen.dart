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
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deferred_state/deferred_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../../../dao/accounting_registers.dart';
import '../../../../dao/dao.g.dart';
import '../../../../src/version/version.g.dart';
import '../../../../util/dart/format.dart';
import '../../../../util/dart/local_date.dart';
import '../../../../util/dart/money_ex.dart';
import '../../../dialog/email_dialog.dart';
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/widgets.g.dart';
import 'accounting_import_screen.dart';
import 'accounting_period_selector.dart';
import 'report_csv_export.dart';

class AccountantTaxPackScreen extends StatefulWidget {
  const AccountantTaxPackScreen({super.key});

  @override
  State<AccountantTaxPackScreen> createState() =>
      _AccountantTaxPackScreenState();
}

class _AccountantTaxPackScreenState
    extends DeferredState<AccountantTaxPackScreen> {
  late AccountingPeriod _initialPeriod;
  AccountingPeriod? _period;
  var _building = false;

  @override
  Future<void> asyncInitState() async {
    _initialPeriod = await BlockingUI().runAndWait(
      () => AccountingPeriod.forFinancialYear(DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Accountant Tax Pack')),
    body: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, error) => Text('Unable to load period: $error'),
      builder: (context) {
        _period ??= _initialPeriod;
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
                      'Creates a ZIP with an Excel workbook, detailed CSV '
                      'registers and reconciliation notes.',
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
                      label: 'Xero / QuickBooks invoice files',
                      hint: 'Prepare mapped sales invoice import files',
                      icon: const Icon(Icons.upload_file),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              AccountingImportScreen(period: period),
                        ),
                      ),
                    ),
                    HMBButton.withIcon(
                      label: 'Save Tax Pack',
                      icon: const Icon(Icons.save_alt),
                      hint: 'Save the workbook and detailed registers',
                      enabled: !_building,
                      onPressed: () => _sendTaxPack(period, save: true),
                    ),
                    HMBButton.withIcon(
                      label: _building ? 'Preparing...' : 'Send Tax Pack',
                      hint: 'Prepare and email the accountant tax report pack',
                      icon: const Icon(Icons.email),
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

  Future<void> _sendTaxPack(
    AccountingPeriod period, {
    bool save = false,
  }) async {
    setState(() => _building = true);
    try {
      final file = await BlockingUI().runAndWait(() => _buildWorkbook(period));
      if (save) {
        await FilePicker.saveFile(
          dialogTitle: 'Save accountant tax pack',
          fileName: file.uri.pathSegments.last,
          bytes: Uint8List.fromList(await file.readAsBytes()),
        );
        return;
      }
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

  Future<File> _buildWorkbook(AccountingPeriod period) =>
      AccountantTaxPackBuilder().build(period);

  String _periodLabel(AccountingPeriod period) {
    final endInclusive = period.endExclusive.subtract(const Duration(days: 1));
    return '${formatDate(period.startInclusive, format: 'j M Y')} to '
        '${formatDate(endInclusive, format: 'j M Y')}';
  }
}

class AccountantTaxPackBuilder {
  Future<File> build(AccountingPeriod period) async {
    const limitations =
        'Unknown tax is not estimated. '
        'Net amounts for these documents are provisional.';
    const exclusions =
        'Bank reconciliation, balance sheet, payroll, depreciation '
        'and supplier payment timing are accountant-managed.';
    const sourceIdentity =
        'IDs are stable within this HMB database. '
        'Repeated exports contain the same records; do not import twice.';
    final label = await AccountingReportService.resolveTaxLabel();
    final system = await DaoSystem().get();
    final endInclusive = period.endExclusive.subtract(const Duration(days: 1));

    final workbook = await DaoInvoice().db.transaction((txn) async {
      final service = AccountingReportService(
        snapshot: txn,
        taxLabel: label,
        externalAccountingEnabled: system.isExternalAccountingEnabled(),
      );
      final profitAndLoss = await service.profitAndLoss(period);
      final taxSummary = await service.taxSummary(period);
      final cashReceived = await service.cashReceived(period);
      final receiptDetails = await _receiptDetails(period, txn);
      final supplierSpend = await service.supplierSpend(period);
      final debtorStatement = await service.debtorStatement(
        customerId: null,
        startInclusive: period.startInclusive,
        endExclusive: period.endExclusive,
      );
      final agedReceivables = await service.agedReceivables(
        asOfDate: LocalDate.fromDateTime(endInclusive),
      );
      final unlinkedCosts = await service.unlinkedCosts(period: period);

      final registers = await AccountingRegisters.load(txn, period);
      return _Workbook([
        _Sheet('Manifest', [
          ['Field', 'Value'],
          ['Business', system.businessName],
          ['Currency', 'AUD'],
          ['Period starts', period.startInclusive],
          ['Period ends (exclusive)', period.endExclusive],
          ['Generated', DateTime.now().toIso8601String()],
          [
            'Schema version',
            (await txn.rawQuery(
              'SELECT MAX(db_version) AS version FROM version',
            )).single['version'],
          ],
          ['Application version', packageVersion],
          ['Basis', 'Issued sales less recorded tax; receipts net of tax'],
          ['Unknown tax documents', taxSummary.unknownTaxDocuments],
          ['Limitations', limitations],
          ['Exclusions', exclusions],
          ['Source identity', sourceIdentity],
          [
            'Review scope',
            'Billing review includes all unresolved historical exceptions.',
          ],
          for (final register in registers.entries)
            ['${register.key} rows', register.value.length - 1],
        ]),
        for (final register in registers.entries)
          _Sheet(register.key, register.value),
        _Sheet('Profit and Loss', _profitAndLossRows(profitAndLoss)),
        _Sheet('Tax Summary', _taxSummaryRows(taxSummary)),
        _Sheet('Customer Payments', _cashReceivedRows(cashReceived)),
        _Sheet('Receipts', receiptDetails),
        _Sheet('Supplier Spend', _supplierSpendRows(supplierSpend)),
        _Sheet('Debtor Activity', _debtorStatementRows(debtorStatement)),
        _Sheet('Aged Receivables', _agedReceivablesRows(agedReceivables)),
        _Sheet('Unlinked Costs', _unlinkedCostRows(unlinkedCosts)),
      ]);
    });
    final archiveDirectory = Directory(
      '${File(DaoInvoice().db.path).parent.path}/accountant_exports',
    );
    await archiveDirectory.create(recursive: true);
    final dir = await archiveDirectory.createTemp('hmb_tax_pack_');
    final file = File(
      '${dir.path}/${accountingReportExportFileName(reportName: 'accountant_tax_pack', extension: 'zip', startInclusive: period.startInclusive, endInclusive: endInclusive)}',
    );
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes('accountant_workbook.xlsx', _buildXlsx(workbook)),
      );
    for (final sheet in workbook.sheets) {
      archive.addFile(
        ArchiveFile.string(
          '${sheet.name}.csv',
          accountingRegisterCsv(sheet.rows),
        ),
      );
    }
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
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
    ['Documents with unknown tax', report.unknownTaxDocuments],
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

  Future<List<List<Object?>>> _receiptDetails(
    AccountingPeriod period,
    DatabaseExecutor db,
  ) async {
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
  <cellXfs count="3"><xf fontId="0"/><xf fontId="1" applyFont="1"/><xf numFmtId="4" applyNumberFormat="1"/></cellXfs>
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
  if (value is Money) {
    return '<c r="$ref" s="2"><v>${(value.minorUnits.toInt() / 100).toStringAsFixed(2)}</v></c>';
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
