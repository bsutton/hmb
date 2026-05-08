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

class DaoCreditAllocation extends Dao<CreditAllocation> {
  static const tableName = 'credit_allocation';
  DaoCreditAllocation() : super(tableName);

  @override
  CreditAllocation fromMap(Map<String, dynamic> map) =>
      CreditAllocation.fromMap(map);

  Future<List<CreditAllocation>> getByInvoiceId(int invoiceId) async {
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

  Future<List<CreditAllocation>> getByCreditNoteId(int creditNoteId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'credit_note_id = ?',
        whereArgs: [creditNoteId],
        orderBy: 'allocated_date ASC, id ASC',
      ),
    );
  }

  Future<Money> totalForInvoice(int invoiceId) =>
      _sum(where: 'invoice_id = ?', whereArgs: [invoiceId]);

  Future<Money> totalForCreditNote(int creditNoteId) =>
      _sum(where: 'credit_note_id = ?', whereArgs: [creditNoteId]);

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
