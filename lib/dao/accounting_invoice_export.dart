import 'package:archive/archive.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'accounting_registers.dart';
import 'accounting_report_service.dart';
import 'dao_invoice.dart';

enum AccountantImportTarget { xero, quickBooksAustralia, quickBooksUS }

class InvoiceExportData {
  final List<Map<String, Object?>> invoices;
  final List<Map<String, Object?>> lines;
  final AccountingPeriod period;
  const InvoiceExportData(this.invoices, this.lines, this.period);

  Map<int, String> get customers => {
    for (final invoice in invoices)
      if (invoice['customer_id'] case final int id)
        id: invoice['customer_name'] as String? ?? '',
  };

  Set<String> get taxKeys => lines.map(taxKey).toSet();

  static String taxKey(Map<String, Object?> line) =>
      '${line['tax_code_id'] ?? line['tax_type'] ?? 'unknown'}';
}

class ImportTaxMapping {
  final String targetCode;
  final double ratePercent;
  const ImportTaxMapping(this.targetCode, this.ratePercent);
}

class InvoiceImportFiles {
  final Map<String, String> files;
  final int invoiceCount;
  final List<List<Object?>> exclusions;
  const InvoiceImportFiles(this.files, this.invoiceCount, this.exclusions);

  List<int> zip() {
    final archive = Archive();
    for (final file in files.entries) {
      archive.addFile(ArchiveFile.string(file.key, file.value));
    }
    return ZipEncoder().encodeBytes(archive);
  }
}

/// File generation is read-only: no sending, payment or export flags change.
class AccountingInvoiceExport {
  Future<InvoiceExportData> load(AccountingPeriod period) =>
      DaoInvoice().db.transaction((txn) => loadSnapshot(txn, period));

  Future<InvoiceExportData> loadSnapshot(
    DatabaseExecutor db,
    AccountingPeriod period,
  ) async {
    final args = [
      period.startInclusive.toIso8601String(),
      period.endExclusive.toIso8601String(),
    ];
    final invoices = await db.rawQuery('''
SELECT i.*, COALESCE(i.billing_customer_id, j.bill_to_customer_id, j.customer_id)
 AS customer_id, c.name AS customer_name,
 EXISTS(SELECT 1 FROM quickbooks_invoice_export q WHERE q.invoice_id = i.id)
 AS has_quickbooks_export
FROM invoice i LEFT JOIN job j ON j.id = i.job_id
LEFT JOIN customer c ON c.id =
 COALESCE(i.billing_customer_id, j.bill_to_customer_id, j.customer_id)
WHERE COALESCE(i.issued_date, i.created_date) >= ?
 AND COALESCE(i.issued_date, i.created_date) < ? ORDER BY i.id
''', args);
    final lines = await db.rawQuery('''
SELECT l.* FROM invoice_line l JOIN invoice i ON i.id = l.invoice_id
WHERE COALESCE(i.issued_date, i.created_date) >= ?
 AND COALESCE(i.issued_date, i.created_date) < ? ORDER BY i.id, l.id
''', args);
    return InvoiceExportData(invoices, lines, period);
  }

  InvoiceImportFiles build(
    InvoiceExportData data, {
    required AccountantImportTarget target,
    required Map<int, String> customers,
    required Map<String, ImportTaxMapping> taxMappings,
    String revenueAccount = '',
    Set<int> alreadyImported = const {},
  }) {
    if (target == AccountantImportTarget.xero &&
        revenueAccount.trim().isEmpty) {
      throw ArgumentError('Enter the revenue account code from Xero.');
    }
    final xero = target == AccountantImportTarget.xero;
    final headers = xero
        ? [
            '*ContactName',
            '*InvoiceNumber',
            '*InvoiceDate',
            '*DueDate',
            'Description',
            '*Quantity',
            '*UnitAmount',
            '*AccountCode',
            '*TaxType',
            'Currency',
          ]
        : [
            'Invoice number',
            'Customer',
            'Invoice date',
            'Due date',
            'Item description',
            'Item amount',
            if (target == AccountantImportTarget.quickBooksAustralia)
              'Item tax code',
          ];
    final batches = <List<List<Object?>>>[];
    var rows = <List<Object?>>[headers];
    var batchInvoices = 0;
    var count = 0;
    final numbers = <String>{};
    final excluded = <List<Object?>>[
      ['HMB invoice ID', 'Reason'],
    ];
    final identities = <List<Object?>>[
      [
        'HMB invoice ID',
        'Import invoice number',
        'Gross AUD',
        'Recorded tax AUD',
      ],
    ];
    for (final invoice in data.invoices) {
      final id = invoice['id']! as int;
      final lines = data.lines.where((l) => l['invoice_id'] == id).toList();
      final number = (invoice['invoice_num'] as String?)?.trim();
      final identity = number == null || number.isEmpty ? 'HMB-$id' : number;
      final customer = customers[invoice['customer_id']]?.trim() ?? '';
      String? reason;
      if (invoice['accounting_state'] == 'draft') {
        reason = 'Draft';
      }
      if ([2, 3].contains(invoice['external_sync_status'])) {
        reason = 'Voided or deleted';
      }
      if ((invoice['external_invoice_id'] as String?)?.isNotEmpty ?? false) {
        reason = 'Already linked to an accounting integration';
      }
      if (invoice['has_quickbooks_export'] == 1) {
        reason = 'QuickBooks export history exists';
      }
      if (alreadyImported.contains(id)) {
        reason = 'Previously imported (user selection)';
      }
      if (customer.isEmpty) {
        reason = 'Missing target customer name';
      }
      if ([
        customer,
        identity,
        revenueAccount,
      ].any((value) => RegExp(r'^[=+@\-\t\r]').hasMatch(value))) {
        reason = 'Target identity cannot be preserved safely in CSV';
      }
      if (lines.isEmpty) {
        reason = 'No detailed sales lines';
      }
      if (lines.length > 1000) {
        reason = 'Invoice exceeds 1000 import rows';
      }
      if (numbers.contains(identity)) {
        reason = 'Duplicate invoice number in this export';
      }
      var gross = 0;
      var tax = 0;
      for (final line in lines) {
        final amount = line['line_total']! as int;
        final recordedTax = line['tax_amount'] as int? ?? 0;
        gross += amount;
        tax += recordedTax;
        if (amount < 0) {
          reason = 'Negative charges require separate review';
        }
        final mapping = taxMappings[InvoiceExportData.taxKey(line)];
        if (mapping == null ||
            mapping.targetCode.trim().isEmpty ||
            !mapping.ratePercent.isFinite ||
            mapping.ratePercent < 0) {
          reason = 'Missing tax mapping';
        } else if ((amount * mapping.ratePercent / (100 + mapping.ratePercent))
                .round() !=
            recordedTax) {
          reason = 'Mapped tax rate does not reproduce stored tax';
        }
        if (mapping != null &&
            RegExp(r'^[=+@\-\t\r]').hasMatch(mapping.targetCode)) {
          reason = 'Target tax code cannot be preserved safely in CSV';
        }
        if (line['tax_code_id'] == null &&
            ((line['tax_type'] as String?)?.isEmpty ?? true) &&
            recordedTax == 0 &&
            amount != 0) {
          reason = 'Historical tax is unknown';
        }
        if (target == AccountantImportTarget.quickBooksUS && recordedTax != 0) {
          reason = 'US CSV import does not support sales tax';
        }
      }
      if (gross != invoice['total_amount']) {
        reason = 'Invoice and line totals do not reconcile';
      }
      if (gross <= 0) {
        reason = 'Non-positive invoice requires separate review';
      }
      if (reason != null) {
        excluded.add([id, reason]);
        continue;
      }
      if (batchInvoices >= 100 || rows.length + lines.length > 1001) {
        batches.add(rows);
        rows = [headers];
        batchInvoices = 0;
      }
      String date(Object? value) {
        final d = DateTime.parse(value! as String);
        return '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}';
      }

      for (final line in lines) {
        final amount = ((line['line_total']! as int) / 100).toStringAsFixed(2);
        final mapping = taxMappings[InvoiceExportData.taxKey(line)]!;
        rows.add(
          xero
              ? [
                  customer,
                  identity,
                  date(invoice['issued_date'] ?? invoice['created_date']),
                  date(invoice['due_date']),
                  line['description'],
                  1,
                  amount,
                  revenueAccount.trim(),
                  mapping.targetCode.trim(),
                  'AUD',
                ]
              : [
                  identity,
                  customer,
                  date(invoice['issued_date'] ?? invoice['created_date']),
                  date(invoice['due_date']),
                  line['description'],
                  amount,
                  if (target == AccountantImportTarget.quickBooksAustralia)
                    mapping.targetCode.trim(),
                ],
        );
      }
      numbers.add(identity);
      identities.add([
        id,
        identity,
        (gross / 100).toStringAsFixed(2),
        (tax / 100).toStringAsFixed(2),
      ]);
      count++;
      batchInvoices++;
    }
    if (rows.length > 1) {
      batches.add(rows);
    }
    final files = <String, String>{
      for (var i = 0; i < batches.length; i++)
        '${target.name}_invoices_${i + 1}.csv': accountingRegisterCsv(
          batches[i],
        ),
      'excluded_invoices.csv': accountingRegisterCsv(excluded),
      'source_manifest.csv': accountingRegisterCsv(identities),
      'IMPORT_INSTRUCTIONS.txt':
          '''
Target: ${target.name}. Currency: AUD. Dates: DD/MM/YYYY.
Amounts are TAX INCLUSIVE; choose Inclusive in the importer.
Each HMB line is exported as one priced item to preserve its recorded cents.
Xero account and tax names must match the target organisation exactly.
QuickBooks Australia: map the supplied GST codes and select Inclusive.
QuickBooks US: only use an organisation without sales tax enabled.
Match customers before importing. Do not automatically create duplicates.
Enable custom transaction numbers in QuickBooks and preserve supplied numbers.
These are sales invoices only. Payments, credits, receipts and adjustments
are in the accountant pack and are NOT imported by these files.
Import into a test organisation first and reconcile counts, gross, tax and
outstanding balances against the source manifest and accountant registers.
Exporting does not mark invoices sent, paid or imported.
Retain the manifest and record successfully imported HMB IDs. On retry,
exclude those IDs; re-importing an overlapping file can create duplicates.
A file cannot inspect the target account or guarantee duplicate prevention.
Partial failures: import only failed invoices after checking the target.
Selected period: ${data.period.startInclusive} to ${data.period.endExclusive} (exclusive).
Included invoices: $count. Excluded invoices: ${excluded.length - 1}.
Sources:
https://central.xero.com/0/article/Import-customer-invoices-GL
https://quickbooks.intuit.com/learn-support/en-au/help-article/import-export-files/import-multiple-invoices/L7E9Xrd8l_AU_en_AU
https://quickbooks.intuit.com/learn-support/en-us/help-article/import-export-data-files/import-multiple-invoices/L7E9Xrd8l_US_en_US
''',
    };
    return InvoiceImportFiles(files, count, excluded);
  }
}
