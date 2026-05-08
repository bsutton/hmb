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

class DaoDebtorTransaction extends Dao<DebtorTransaction> {
  static const tableName = 'debtor_transaction';
  DaoDebtorTransaction() : super(tableName);

  @override
  DebtorTransaction fromMap(Map<String, dynamic> map) =>
      DebtorTransaction.fromMap(map);

  Future<DebtorTransaction?> getBySource({
    required DebtorTransactionType type,
    required String sourceTable,
    required int sourceId,
  }) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: '''
transaction_type = ?
AND source_table = ?
AND source_id = ?
''',
      whereArgs: [type.ordinal, sourceTable, sourceId],
    );
    return rows.isEmpty ? null : fromMap(rows.first);
  }

  Future<List<DebtorTransaction>> getByInvoiceId(int invoiceId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'source_table = ? AND source_id = ?',
        whereArgs: ['invoice', invoiceId],
      ),
    );
  }
}
