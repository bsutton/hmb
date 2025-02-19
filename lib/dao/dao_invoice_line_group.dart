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
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'modified_date desc',
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<InvoiceLineGroup>> getByInvoiceId(
    int invoiceId, [
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
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
