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

import 'package:money2/money2.dart';

import '../entity/entity.g.dart';
import '../util/dart/money_ex.dart';
import 'dao.dart';

class DaoDebtorPayment extends Dao<DebtorPayment> {
  static const tableName = 'debtor_payment';
  DaoDebtorPayment() : super(tableName);

  @override
  DebtorPayment fromMap(Map<String, dynamic> map) => DebtorPayment.fromMap(map);

  Future<List<DebtorPayment>> getRecent({
    bool includeFullyAllocated = true,
  }) async {
    final db = withoutTransaction();
    final includeAllocatedFlag = includeFullyAllocated ? 1 : 0;
    final rows = await db.rawQuery(
      '''
SELECT p.*
FROM $tableName p
LEFT JOIN (
  SELECT payment_id, SUM(amount) AS allocated
  FROM debtor_payment_allocation
  GROUP BY payment_id
) a ON a.payment_id = p.id
WHERE ? = 1 OR IFNULL(a.allocated, 0) < p.amount
ORDER BY p.payment_date DESC, p.id DESC
''',
      [includeAllocatedFlag],
    );
    return toList(rows);
  }

  Future<List<DebtorPayment>> getUnallocatedForCustomer(int customerId) async {
    final db = withoutTransaction();
    final rows = await db.rawQuery(
      '''
SELECT p.*
FROM $tableName p
LEFT JOIN (
  SELECT payment_id, SUM(amount) AS allocated
  FROM debtor_payment_allocation
  GROUP BY payment_id
) a ON a.payment_id = p.id
WHERE p.customer_id = ?
AND IFNULL(a.allocated, 0) < p.amount
ORDER BY p.payment_date ASC, p.id ASC
''',
      [customerId],
    );
    return toList(rows);
  }

  Future<Money> allocatedAmount(int paymentId) async {
    final db = withoutTransaction();
    final rows = await db.rawQuery(
      '''
SELECT IFNULL(SUM(amount), 0) AS total
FROM debtor_payment_allocation
WHERE payment_id = ?
''',
      [paymentId],
    );
    return MoneyEx.fromInt(rows.first['total'] as int? ?? 0);
  }

  Future<Money> unallocatedAmount(DebtorPayment payment) async =>
      payment.amount - await allocatedAmount(payment.id);

  Future<DebtorPayment?> getByExternalPaymentId({
    required String provider,
    required String externalPaymentId,
  }) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'external_provider = ? AND external_payment_id = ?',
      whereArgs: [provider, externalPaymentId],
      limit: 1,
    );
    return getFirstOrNull(rows);
  }

  Future<List<DebtorPayment>> getUnsyncedForProvider(String provider) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where:
            '(external_provider IS NULL OR external_provider != ?) '
            'AND (external_payment_id IS NULL OR external_payment_id = ?)',
        whereArgs: [provider, ''],
        orderBy: 'payment_date ASC, id ASC',
      ),
    );
  }

  Future<void> markExternal({
    required DebtorPayment payment,
    required String provider,
    required String externalPaymentId,
  }) async {
    await update(
      DebtorPayment(
        id: payment.id,
        customerId: payment.customerId,
        contactId: payment.contactId,
        paymentDate: payment.paymentDate,
        amount: payment.amount,
        paymentMethod: payment.paymentMethod,
        reference: payment.reference,
        notes: payment.notes,
        externalPaymentId: externalPaymentId,
        externalProvider: provider,
        createdDate: payment.createdDate,
        modifiedDate: DateTime.now(),
      ),
    );
  }
}
