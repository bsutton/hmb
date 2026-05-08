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
import 'dao.dart';

class DaoPaymentAllocation extends Dao<PaymentAllocation> {
  static const tableName = 'debtor_payment_allocation';
  DaoPaymentAllocation() : super(tableName);

  @override
  PaymentAllocation fromMap(Map<String, dynamic> map) =>
      PaymentAllocation.fromMap(map);

  Future<List<PaymentAllocation>> getByInvoiceId(int invoiceId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
        orderBy: 'allocated_date ASC, id ASC',
      ),
    );
  }

  Future<List<PaymentAllocation>> getByPaymentId(int paymentId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'payment_id = ?',
        whereArgs: [paymentId],
        orderBy: 'allocated_date ASC, id ASC',
      ),
    );
  }

  Future<Money> totalForInvoice(int invoiceId) =>
      _sum(where: 'invoice_id = ?', whereArgs: [invoiceId]);

  Future<Money> totalForPayment(int paymentId) =>
      _sum(where: 'payment_id = ?', whereArgs: [paymentId]);

  Future<Money> _sum({
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = withoutTransaction();
    final rows = await db.rawQuery(
      'SELECT IFNULL(SUM(amount), 0) AS total FROM $tableName WHERE $where',
      whereArgs,
    );
    return Money.fromInt(rows.first['total'] as int? ?? 0, isoCode: 'AUD');
  }
}
