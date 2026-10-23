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

import 'package:sqflite_common/sqlite_api.dart';

import '../entity/invoice_line.dart';
import 'dao.dart';
import 'invoice_lifecycle_service.dart';

class DaoInvoiceLine extends Dao<InvoiceLine> {
  static const tableName = 'invoice_line';
  DaoInvoiceLine() : super(tableName);

  @override
  InvoiceLine fromMap(Map<String, dynamic> map) => InvoiceLine.fromMap(map);

  @override
  Future<List<InvoiceLine>> getAll({
    String? orderByClause,
    Transaction? transaction,
  }) async {
    final db = withinTransaction(transaction);
    return toList(await db.query(tableName, orderBy: 'modified_date desc'));
  }

  Future<List<InvoiceLine>> getByInvoiceId(
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
  Future<int> delete(int id, [Transaction? transaction]) async {
    final count = await InvoiceLifecycleService().deleteLine(
      id,
      transaction: transaction,
    );
    Dao.notifier(this, id);
    return count;
  }

  @override
  Future<int> update(InvoiceLine entity, [Transaction? transaction]) async {
    if (transaction == null) {
      return await db.transaction((txn) => update(entity, txn));
    }
    await InvoiceLifecycleService().validateLineEdit(transaction, entity);
    return await super.update(entity, transaction);
  }

  Future<void> deleteByInvoiceId(
    int invoiceId, [
    Transaction? transaction,
  ]) async {
    if (transaction == null) {
      return await db.transaction((txn) => deleteByInvoiceId(invoiceId, txn));
    }
    for (final line in await getByInvoiceId(invoiceId, transaction)) {
      await delete(line.id, transaction);
    }
  }

  Future<List<InvoiceLine>> getByInvoiceLineGroupId(int id) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'invoice_line_group_id = ?',
        whereArgs: [id],
      ),
    );
  }
}
