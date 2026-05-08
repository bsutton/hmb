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

class DaoDebtorAdjustment extends Dao<DebtorAdjustment> {
  static const tableName = 'debtor_adjustment';
  DaoDebtorAdjustment() : super(tableName);

  @override
  DebtorAdjustment fromMap(Map<String, dynamic> map) =>
      DebtorAdjustment.fromMap(map);

  Future<List<DebtorAdjustment>> getByInvoiceId(int invoiceId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
        orderBy: 'adjustment_date ASC, id ASC',
      ),
    );
  }

  Future<Money> totalForInvoice(int invoiceId) async {
    final db = withoutTransaction();
    final rows = await db.rawQuery(
      '''
SELECT IFNULL(SUM(amount), 0) AS total
FROM $tableName
WHERE invoice_id = ?
''',
      [invoiceId],
    );
    return Money.fromInt(rows.first['total'] as int? ?? 0, isoCode: 'AUD');
  }

  Future<Money> writeOffTotalForInvoice(int invoiceId) async {
    final db = withoutTransaction();
    final rows = await db.rawQuery(
      '''
SELECT IFNULL(SUM(amount), 0) AS total
FROM $tableName
WHERE invoice_id = ?
AND adjustment_type IN (?, ?)
''',
      [
        invoiceId,
        DebtorAdjustmentType.writeOff.ordinal,
        DebtorAdjustmentType.badDebt.ordinal,
      ],
    );
    return Money.fromInt(rows.first['total'] as int? ?? 0, isoCode: 'AUD');
  }
}
