import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/quote_line.dart';
import 'dao.dart';

class DaoQuoteLine extends Dao<QuoteLine> {
  @override
  String get tableName => 'quote_line';

  @override
  QuoteLine fromMap(Map<String, dynamic> map) => QuoteLine.fromMap(map);

  @override
  Future<List<QuoteLine>> getAll({String? orderByClause}) async {
    final db = withoutTransaction();
    return toList(await db.query(tableName, orderBy: 'modified_date desc'));
  }

  Future<List<QuoteLine>> getByQuoteId(int quoteId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'quote_id = ?',
        whereArgs: [quoteId],
        orderBy: 'id desc',
      ),
    );
  }

  Future<List<QuoteLine>> getByQuoteLineGroupId(int quoteLineGroupId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'quote_line_group_id = ?',
        whereArgs: [quoteLineGroupId],
        orderBy: 'id desc',
      ),
    );
  }

  Future<int> deleteByQuoteId(int quoteId, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    return db.delete(tableName, where: 'quote_id = ?', whereArgs: [quoteId]);
  }

  Future<int> deleteByQuoteLineGroupId(
    int quoteLineGroupId, [
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);
    return db.delete(
      tableName,
      where: 'quote_line_group_id = ?',
      whereArgs: [quoteLineGroupId],
    );
  }

  @override
  JuneStateCreator get juneRefresher => QuoteLineState.new;
}

/// Used to notify the UI that the time entry has changed.
class QuoteLineState extends JuneState {
  QuoteLineState();
}
