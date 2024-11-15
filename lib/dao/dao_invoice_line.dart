import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/invoice_line.dart';
import 'dao.dart';
import 'dao_checklist_item.dart';
import 'dao_job.dart';
import 'dao_time_entry.dart';

class DaoInvoiceLine extends Dao<InvoiceLine> {
  @override
  String get tableName => 'invoice_line';

  @override
  InvoiceLine fromMap(Map<String, dynamic> map) => InvoiceLine.fromMap(map);

  @override
  Future<List<InvoiceLine>> getAll(
      {String? orderByClause, Transaction? transaction}) async {
    final db = withinTransaction(transaction);
    final List<Map<String, dynamic>> maps =
        await db.query(tableName, orderBy: 'modified_date desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<InvoiceLine>> getByInvoiceId(int invoiceId,
      [Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  /// Deletes all invoice lines for the given invoice id.
  /// and marks all time entries as unbilled.
  Future<void> deleteByInvoiceId(int invoiceId,
      [Transaction? transaction]) async {
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
      await DaoCheckListItem().markNotBilled(line.id);
    }
    await db.delete(tableName, where: 'invoice_id =?', whereArgs: [invoiceId]);
  }

  @override
  JuneStateCreator get juneRefresher => InvoiceLineState.new;

  Future<List<InvoiceLine>> getByInvoiceLineGroupId(int id) async {
    final db = withoutTransaction();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'invoice_line_group_id = ?',
      whereArgs: [id],
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }
}

/// Used to notify the UI that the time entry has changed.
class InvoiceLineState extends JuneState {
  InvoiceLineState();
}
