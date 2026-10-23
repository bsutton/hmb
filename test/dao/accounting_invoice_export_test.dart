import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/accounting_invoice_export.dart';
import 'package:hmb/dao/accounting_report_service.dart';

void main() {
  Map<String, Object?> invoice(int id) => {
    'id': id,
    'invoice_num': 'INV-$id',
    'customer_id': 7,
    'customer_name': 'Example Customer',
    'accounting_state': 'issued',
    'created_date': '2026-06-01T09:00:00',
    'issued_date': '2026-06-02T09:00:00',
    'due_date': '2026-06-16',
    'total_amount': 11000,
    'external_sync_status': 0,
    'external_invoice_id': null,
    'has_quickbooks_export': 0,
  };
  Map<String, Object?> line(int invoiceId) => {
    'id': invoiceId,
    'invoice_id': invoiceId,
    'description': 'Agreed work',
    'line_total': 11000,
    'tax_amount': 1000,
    'tax_type': 'OUTPUT',
    'tax_code_id': null,
  };
  final service = AccountingInvoiceExport();
  final period = AccountingPeriod.month(2026, 6);
  const mappings = {'OUTPUT': ImportTaxMapping('GST on Income', 10)};

  test(
    'Xero and Australian QuickBooks preserve inclusive totals and identities',
    () {
      final data = InvoiceExportData([invoice(1)], [line(1)], period);
      for (final target in [
        AccountantImportTarget.xero,
        AccountantImportTarget.quickBooksAustralia,
      ]) {
        final result = service.build(
          data,
          target: target,
          customers: {7: 'Exact target name'},
          taxMappings: mappings,
          revenueAccount: '200',
        );
        expect(result.invoiceCount, 1);
        final csv = result.files.entries
            .firstWhere((f) => f.key.endsWith('_1.csv'))
            .value;
        expect(csv, contains('"110.00"'));
        expect(csv, contains('"INV-1"'));
        expect(csv, contains('"02/06/2026"'));
        expect(csv, contains('"Exact target name"'));
        expect(result.files['source_manifest.csv'], contains('"10.00"'));
        expect(result.exclusions, hasLength(1));
      }
    },
  );

  test(
    'US sales tax, unknown tax, prior imports and integrations are excluded',
    () {
      final data = InvoiceExportData([invoice(1)], [line(1)], period);
      final us = service.build(
        data,
        target: AccountantImportTarget.quickBooksUS,
        customers: data.customers,
        taxMappings: mappings,
      );
      expect(us.invoiceCount, 0);
      expect(us.exclusions.last.last, contains('sales tax'));
      final imported = service.build(
        data,
        target: AccountantImportTarget.xero,
        customers: data.customers,
        taxMappings: mappings,
        revenueAccount: '200',
        alreadyImported: {1},
      );
      expect(imported.invoiceCount, 0);
      final linked = InvoiceExportData(
        [invoice(1)..['external_invoice_id'] = 'external-1'],
        [line(1)],
        period,
      );
      expect(
        service
            .build(
              linked,
              target: AccountantImportTarget.xero,
              customers: data.customers,
              taxMappings: mappings,
              revenueAccount: '200',
            )
            .invoiceCount,
        0,
      );
      final unknown = InvoiceExportData(
        [invoice(1)..['total_amount'] = 11000],
        [
          line(1)
            ..['tax_amount'] = 0
            ..['tax_type'] = null,
        ],
        period,
      );
      expect(
        service
            .build(
              unknown,
              target: AccountantImportTarget.xero,
              customers: data.customers,
              taxMappings: {'unknown': const ImportTaxMapping('No GST', 0)},
              revenueAccount: '200',
            )
            .invoiceCount,
        0,
      );
    },
  );

  test('invalid mapping and inconsistent totals exclude whole invoices', () {
    final data = InvoiceExportData([invoice(1)], [line(1)], period);
    final result = service.build(
      data,
      target: AccountantImportTarget.xero,
      customers: data.customers,
      taxMappings: {'OUTPUT': const ImportTaxMapping('Wrong GST', 20)},
      revenueAccount: '200',
    );
    expect(result.invoiceCount, 0);
    expect(result.exclusions.last.last, contains('stored tax'));
    final mismatch = InvoiceExportData(
      [invoice(1)..['total_amount'] = 12000],
      [line(1)],
      period,
    );
    expect(
      service
          .build(
            mismatch,
            target: AccountantImportTarget.xero,
            customers: data.customers,
            taxMappings: mappings,
            revenueAccount: '200',
          )
          .exclusions
          .last
          .last,
      contains('reconcile'),
    );
  });

  test(
    'batching respects 100 invoice limit without changing retry identity',
    () {
      final data = InvoiceExportData(
        [for (var i = 1; i <= 101; i++) invoice(i)],
        [for (var i = 1; i <= 101; i++) line(i)],
        period,
      );
      final first = service.build(
        data,
        target: AccountantImportTarget.xero,
        customers: data.customers,
        taxMappings: mappings,
        revenueAccount: '200',
      );
      final retry = service.build(
        data,
        target: AccountantImportTarget.xero,
        customers: data.customers,
        taxMappings: mappings,
        revenueAccount: '200',
      );
      expect(first.invoiceCount, 101);
      expect(
        first.files.keys.where((f) => f.contains('_invoices_')),
        hasLength(2),
      );
      expect(retry.files, first.files);
    },
  );
}
