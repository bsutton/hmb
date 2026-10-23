import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../util/dart/money_ex.dart';
import 'accounting_report_service.dart';

/// Stable source identifiers and stored monetary values for accountant review.
class AccountingRegisters {
  static const _headers = <String, List<String>>{
    'Sales invoices': [
      'invoice_id',
      'invoice_num',
      'job_id',
      'customer_id',
      'customer_name',
      'accounting_state',
      'invoice_date',
      'due_date',
      'gross',
      'tax',
      'net_recorded',
      'external_invoice_id',
      'external_sync_status',
      'voided_date',
      'tax_provenance',
    ],
    'Sales lines': [
      'line_id',
      'invoice_id',
      'description',
      'quantity',
      'unit_price',
      'gross',
      'tax',
      'net_recorded',
      'tax_type',
      'tax_code_id',
      'status',
    ],
    'Sales movements': [
      'invoice_id',
      'activity_date',
      'activity',
      'gross',
      'tax',
      'net_recorded',
    ],
    'Credit notes': [
      'credit_id',
      'customer_id',
      'related_invoice_id',
      'credit_date',
      'status',
      'reason',
      'gross',
    ],
    'Credit lines': [
      'line_id',
      'credit_note_id',
      'description',
      'quantity',
      'unit_price',
      'gross',
      'tax',
      'tax_type',
      'tax_code_id',
    ],
    'Expense lines': [
      'line_id',
      'receipt_id',
      'receipt_date',
      'supplier_id',
      'description',
      'quantity',
      'expense_category',
      'tax_code_id',
      'net',
      'tax',
      'gross',
      'matched_task_item_id',
    ],
    'Payment register': [
      'payment_id',
      'customer_id',
      'payment_date',
      'amount',
      'payment_method',
      'reference',
      'notes',
      'currently_unallocated',
    ],
    'Payment allocations': [
      'allocation_id',
      'payment_id',
      'invoice_id',
      'allocated_date',
      'amount',
    ],
    'Credit allocations': [
      'allocation_id',
      'credit_note_id',
      'invoice_id',
      'allocated_date',
      'amount',
    ],
    'Adjustments': [
      'adjustment_id',
      'invoice_id',
      'adjustment_date',
      'adjustment_type',
      'amount',
      'reason',
    ],
    'Billing review': ['review_id', 'job_id', 'invoice_id', 'reason'],
    'Receipt reconciliation': [
      'receipt_id',
      'header_gross',
      'lines_gross',
      'difference',
    ],
  };
  static Future<Map<String, List<List<Object?>>>> load(
    DatabaseExecutor db,
    AccountingPeriod period,
  ) async {
    final args = [
      period.startInclusive.toIso8601String(),
      period.endExclusive.toIso8601String(),
    ];
    final result = <String, List<List<Object?>>>{};
    Future<void> register(
      String name,
      String sql, {
      Set<String> money = const {},
      List<Object?>? parameters,
    }) async {
      final rows = await db.rawQuery(sql, parameters ?? args);
      if (rows.isEmpty) {
        result[name] = [_headers[name]!];
        return;
      }
      result[name] = [
        rows.first.keys.toList(),
        for (final row in rows)
          [
            for (final entry in row.entries)
              if (money.contains(entry.key) && entry.value != null)
                MoneyEx.fromInt(entry.value! as int)
              else
                entry.value,
          ],
      ];
    }

    await register(
      'Sales invoices',
      '''
SELECT i.id AS invoice_id, i.invoice_num, i.job_id,
 COALESCE(i.billing_customer_id, j.bill_to_customer_id, j.customer_id) AS customer_id,
 c.name AS customer_name, i.accounting_state,
 COALESCE(i.issued_date, i.created_date) AS invoice_date, i.due_date,
 i.total_amount AS gross, IFNULL(SUM(l.tax_amount), 0) AS tax,
 i.total_amount - IFNULL(SUM(l.tax_amount), 0) AS net_recorded,
 i.external_invoice_id, i.external_sync_status, i.voided_date,
 CASE WHEN COUNT(l.id) = 0 OR SUM(CASE WHEN l.tax_code_id IS NULL
  AND NULLIF(l.tax_type, '') IS NULL AND IFNULL(l.tax_amount, 0) = 0
  AND l.line_total != 0 THEN 1 ELSE 0 END) > 0
 THEN 'unknown' ELSE 'recorded' END AS tax_provenance
FROM invoice i LEFT JOIN job j ON j.id = i.job_id
LEFT JOIN customer c ON c.id =
 COALESCE(i.billing_customer_id, j.bill_to_customer_id, j.customer_id)
LEFT JOIN invoice_line l ON l.invoice_id = i.id
WHERE COALESCE(i.issued_date, i.created_date) >= ?
 AND COALESCE(i.issued_date, i.created_date) < ?
GROUP BY i.id ORDER BY i.id
''',
      money: {'gross', 'tax', 'net_recorded'},
    );
    await register(
      'Sales lines',
      '''
SELECT l.id AS line_id, l.invoice_id, l.description,
 l.quantity / 100.0 AS quantity, l.unit_price, l.line_total AS gross,
 l.tax_amount AS tax, l.line_total - l.tax_amount AS net_recorded,
 l.tax_type, l.tax_code_id, l.status
FROM invoice_line l JOIN invoice i ON i.id = l.invoice_id
WHERE COALESCE(i.issued_date, i.created_date) >= ?
 AND COALESCE(i.issued_date, i.created_date) < ? ORDER BY i.id, l.id
''',
      money: {'unit_price', 'gross', 'tax', 'net_recorded'},
    );
    await register(
      'Sales movements',
      '''
SELECT invoice_id, activity_date, activity, gross, tax,
 gross - tax AS net_recorded FROM (
 SELECT i.id AS invoice_id, COALESCE(i.issued_date, i.created_date) AS activity_date,
 'issued' AS activity, i.total_amount AS gross,
 IFNULL((SELECT SUM(tax_amount) FROM invoice_line WHERE invoice_id = i.id), 0) AS tax
 FROM invoice i WHERE i.accounting_state != 'draft'
 AND (IFNULL(i.external_sync_status, 0) NOT IN (2, 3) OR i.voided_date IS NOT NULL)
 UNION ALL
 SELECT i.id, i.voided_date, 'voided', -i.total_amount,
 -IFNULL((SELECT SUM(tax_amount) FROM invoice_line WHERE invoice_id = i.id), 0)
 FROM invoice i WHERE i.accounting_state != 'draft' AND i.voided_date IS NOT NULL
) WHERE activity_date >= ? AND activity_date < ? ORDER BY activity_date, invoice_id
''',
      money: {'gross', 'tax', 'net_recorded'},
    );
    await register(
      'Credit notes',
      '''
SELECT c.id AS credit_id, c.customer_id, c.related_invoice_id, c.credit_date,
 c.status, c.reason, c.total_amount AS gross
FROM credit_note c WHERE c.credit_date >= ? AND c.credit_date < ?
ORDER BY c.id
''',
      money: {'gross'},
    );
    await register(
      'Credit lines',
      '''
SELECT l.id AS line_id, l.credit_note_id, l.description,
 l.quantity / 100.0 AS quantity, l.unit_price, l.line_total AS gross,
 l.tax_amount AS tax, l.tax_type, l.tax_code_id
FROM credit_note_line l JOIN credit_note c ON c.id = l.credit_note_id
WHERE c.credit_date >= ? AND c.credit_date < ? ORDER BY c.id, l.id
''',
      money: {'unit_price', 'gross', 'tax'},
    );
    await register(
      'Expense lines',
      '''
SELECT l.id AS line_id, l.receipt_id, r.receipt_date, r.supplier_id,
 l.description, l.quantity, l.expense_category, l.tax_code_id,
 l.line_total_ex_tax AS net, l.tax_amount AS tax,
 l.line_total_inc_tax AS gross, l.matched_task_item_id
FROM receipt_line_item l JOIN receipt r ON r.id = l.receipt_id
WHERE r.receipt_date >= ? AND r.receipt_date < ? ORDER BY r.id, l.id
''',
      money: {'net', 'tax', 'gross'},
    );
    await register(
      'Payment register',
      '''
SELECT p.id AS payment_id, p.customer_id, p.payment_date, p.amount,
 p.payment_method, p.reference, p.notes,
 p.amount - IFNULL((SELECT SUM(a.amount) FROM debtor_payment_allocation a
 WHERE a.payment_id = p.id), 0) AS currently_unallocated
FROM debtor_payment p WHERE p.payment_date >= ? AND p.payment_date < ?
ORDER BY p.id
''',
      money: {'amount', 'currently_unallocated'},
    );
    await register(
      'Payment allocations',
      '''
SELECT a.id AS allocation_id, a.payment_id, a.invoice_id,
 a.allocated_date, a.amount FROM debtor_payment_allocation a
WHERE a.allocated_date >= ? AND a.allocated_date < ? ORDER BY a.id
''',
      money: {'amount'},
    );
    await register(
      'Credit allocations',
      '''
SELECT id AS allocation_id, credit_note_id, invoice_id, allocated_date, amount
FROM credit_allocation WHERE allocated_date >= ? AND allocated_date < ?
ORDER BY id
''',
      money: {'amount'},
    );
    await register(
      'Adjustments',
      '''
SELECT id AS adjustment_id, invoice_id, adjustment_date, adjustment_type,
 amount, reason FROM debtor_adjustment
WHERE adjustment_date >= ? AND adjustment_date < ? ORDER BY id
''',
      money: {'amount'},
    );
    await register('Billing review', '''
SELECT id AS review_id, job_id, invoice_id, reason
FROM billing_review WHERE resolved_date IS NULL ORDER BY id
''', parameters: []);
    await register(
      'Receipt reconciliation',
      '''
SELECT r.id AS receipt_id, r.total_including_tax AS header_gross,
 IFNULL(SUM(l.line_total_inc_tax), 0) AS lines_gross,
 r.total_including_tax - IFNULL(SUM(l.line_total_inc_tax), 0) AS difference
FROM receipt r LEFT JOIN receipt_line_item l ON l.receipt_id = r.id
WHERE r.receipt_date >= ? AND r.receipt_date < ?
GROUP BY r.id HAVING difference != 0 ORDER BY r.id
''',
      money: {'header_gross', 'lines_gross', 'difference'},
    );
    return result;
  }
}

String accountingRegisterCsv(List<List<Object?>> rows) => rows
    .map(
      (row) => row
          .map((value) {
            final text = value is Money
                ? (value.minorUnits.toInt() / 100).toStringAsFixed(2)
                : value is DateTime
                ? value.toIso8601String()
                : value?.toString() ?? '';
            // Text must remain text when a spreadsheet opens the CSV.
            final safe =
                value is String && RegExp(r'^[=+@\-\t\r]').hasMatch(text)
                ? "'$text"
                : text;
            return '"${safe.replaceAll('"', '""')}"';
          })
          .join(','),
    )
    .join('\r\n');
