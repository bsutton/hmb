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
  Future<List<QuoteLine>> getAll(
      {String? orderByClause, Transaction? transaction}) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps =
        await db.query(tableName, orderBy: 'modified_date desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<QuoteLine>> getByQuoteId(int quoteId,
      [Transaction? transaction]) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps = await db.query(tableName,
        where: 'quote_id = ?', whereArgs: [quoteId], orderBy: 'id desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<QuoteLine>> getByQuoteLineGroupId(int quoteLineGroupId,
      [Transaction? transaction]) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps = await db.query(tableName,
        where: 'quote_line_group_id = ?',
        whereArgs: [quoteLineGroupId],
        orderBy: 'id desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<int> deleteByQuoteId(int quoteId, [Transaction? transaction]) async {
    final db = getDb(transaction);
    return db.delete(tableName, where: 'quote_id = ?', whereArgs: [quoteId]);
  }

  Future<int> deleteByQuoteLineGroupId(int quoteLineGroupId,
      [Transaction? transaction]) async {
    final db = getDb(transaction);
    return db.delete(tableName,
        where: 'quote_line_group_id = ?', whereArgs: [quoteLineGroupId]);
  }

  @override
  JuneStateCreator get juneRefresher => QuoteLineState.new;
}

/// Used to notify the UI that the time entry has changed.
class QuoteLineState extends JuneState {
  QuoteLineState();
}
