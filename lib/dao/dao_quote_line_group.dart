import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/quote_line_group.dart';
import 'dao.dart';

class DaoQuoteLineGroup extends Dao<QuoteLineGroup> {
  @override
  String get tableName => 'quote_line_group';

  @override
  QuoteLineGroup fromMap(Map<String, dynamic> map) =>
      QuoteLineGroup.fromMap(map);

  @override
  Future<List<QuoteLineGroup>> getAll(
      {String? orderByClause, Transaction? transaction}) async {
    final db = withinTransaction(transaction);
    final List<Map<String, dynamic>> maps =
        await db.query(tableName, orderBy: 'modified_date asc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<QuoteLineGroup>> getByQuoteId(int quoteId,
      [Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    final List<Map<String, dynamic>> maps = await db.query(tableName,
        where: 'quote_id = ?', whereArgs: [quoteId], orderBy: 'id asc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<int> deleteByQuoteId(int quoteId, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    return db.delete(tableName, where: 'quote_id = ?', whereArgs: [quoteId]);
  }

  @override
  JuneStateCreator get juneRefresher => QuoteGroupLineState.new;
}

/// Used to notify the UI that the time entry has changed.
class QuoteGroupLineState extends JuneState {
  QuoteGroupLineState();
}
