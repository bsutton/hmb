/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/invoice_line_group.dart';
import 'dao.dart';

class DaoInvoiceLineGroup extends Dao<InvoiceLineGroup> {
  @override
  String get tableName => 'invoice_line_group';

  @override
  InvoiceLineGroup fromMap(Map<String, dynamic> map) =>
      InvoiceLineGroup.fromMap(map);

  @override
  Future<List<InvoiceLineGroup>> getAll({
    String? orderByClause,
    Transaction? transaction,
  }) async {
    final db = withinTransaction(transaction);
    return toList(await db.query(tableName, orderBy: 'modified_date desc'));
  }

  Future<List<InvoiceLineGroup>> getByInvoiceId(
    int invoiceId, [
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);
    return toList(
      await db.query(
        tableName,
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      ),
    );
  }

  @override
  JuneStateCreator get juneRefresher => InvoiceLineGroupState.new;

  Future<void> deleteByInvoiceId(
    int invoiceId, [
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);

    await db.delete(tableName, where: 'invoice_id =?', whereArgs: [invoiceId]);
  }
}

/// Used to notify the UI that the time entry has changed.
class InvoiceLineGroupState extends JuneState {
  InvoiceLineGroupState();
}
