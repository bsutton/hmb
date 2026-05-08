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

import '../entity/entity.g.dart';
import 'dao.dart';

class DaoDebtorPayment extends Dao<DebtorPayment> {
  static const tableName = 'debtor_payment';
  DaoDebtorPayment() : super(tableName);

  @override
  DebtorPayment fromMap(Map<String, dynamic> map) => DebtorPayment.fromMap(map);

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
