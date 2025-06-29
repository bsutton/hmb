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

import '../entity/invoice_line.dart';
import 'dao.dart';
import 'dao_job.dart';
import 'dao_task_item.dart';
import 'dao_time_entry.dart';

class DaoInvoiceLine extends Dao<InvoiceLine> {
  @override
  String get tableName => 'invoice_line';

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

  /// Deletes all invoice lines for the given invoice id.
  /// and marks all time entries as unbilled.
  Future<void> deleteByInvoiceId(
    int invoiceId, [
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);
    final lines = await getByInvoiceId(invoiceId);
    for (final line in lines) {
      if (line.fromBookingFee) {
        final job = await DaoJob().getJobForInvoice(invoiceId);
        await DaoJob().markBookingFeeNotBilled(job);
      }

      /// try each of the source types and if they
      /// have a matching line id then mark them as
      /// not billed.
      await DaoTimeEntry().markAsNotbilled(line.id);
      await DaoTaskItem().markNotBilled(line.id);
    }
    await db.delete(tableName, where: 'invoice_id =?', whereArgs: [invoiceId]);
  }

  @override
  JuneStateCreator get juneRefresher => InvoiceLineState.new;

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

/// Used to notify the UI that the time entry has changed.
class InvoiceLineState extends JuneState {
  InvoiceLineState();
}
