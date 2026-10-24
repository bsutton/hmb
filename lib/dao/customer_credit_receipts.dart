import 'package:money2/money2.dart';

import '../util/dart/money_ex.dart';
import 'dao_debtor_payment.dart';

/// Read-only receipts managed by the accounting integration.
class CustomerCreditReceipt {
  final String customerName;
  final DateTime date;
  final String kind;
  final String? reference;
  final Money amount;
  final Money allocated;
  final Money refunded;
  final Money remaining;

  CustomerCreditReceipt.fromMap(Map<String, Object?> row)
    : customerName = row['customer_name']! as String,
      date = DateTime.parse(row['credit_date']! as String),
      kind = row['credit_kind']! as String,
      reference = row['reference'] as String?,
      amount = MoneyEx.fromInt(row['amount']! as int),
      allocated = MoneyEx.fromInt(row['allocated']! as int),
      refunded = MoneyEx.fromInt(row['refunded']! as int),
      remaining = MoneyEx.fromInt(row['remaining_credit']! as int);

  String get label => kind == 'prepayment' ? 'Prepayment' : 'Overpayment';
}

Future<List<CustomerCreditReceipt>> loadCustomerCreditReceipts({
  required DateTime startInclusive,
  required DateTime endExclusive,
  int? customerId,
  bool includeFullyAllocated = true,
  String search = '',
}) async {
  final rows = await DaoDebtorPayment().withoutTransaction().rawQuery(
    '''
SELECT c.*, customer.name AS customer_name,
 COALESCE(e.allocated, 0) AS allocated, COALESCE(e.refunded, 0) AS refunded
FROM xero_customer_credit c
JOIN customer ON customer.id = c.customer_id
LEFT JOIN (
 SELECT tenant_id, credit_id,
 SUM(CASE WHEN kind = 'allocation' THEN amount ELSE 0 END) AS allocated,
 SUM(CASE WHEN kind = 'refund' THEN amount ELSE 0 END) AS refunded
 FROM xero_customer_credit_event GROUP BY tenant_id, credit_id
) e ON e.tenant_id = c.tenant_id AND e.credit_id = c.external_id
WHERE c.credit_kind IN ('overpayment', 'prepayment') AND c.amount > 0
 AND julianday(c.credit_date) >= julianday(?)
 AND julianday(c.credit_date) < julianday(?)
 AND (? IS NULL OR c.customer_id = ?)
 AND (? = 1 OR c.remaining_credit > 0)
 AND (LOWER(customer.name) LIKE ? OR LOWER(COALESCE(c.reference, '')) LIKE ?
      OR LOWER(c.credit_kind) LIKE ?)
ORDER BY c.credit_date DESC, c.external_id
''',
    [
      startInclusive.toIso8601String(),
      endExclusive.toIso8601String(),
      customerId,
      customerId,
      if (includeFullyAllocated) 1 else 0,
      for (var i = 0; i < 3; i++) '%${search.trim().toLowerCase()}%',
    ],
  );
  return rows.map(CustomerCreditReceipt.fromMap).toList();
}
