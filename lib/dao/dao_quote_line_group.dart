import 'package:june/state_manager/src/simple/controllers.dart';
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
  Future<List<QuoteLineGroup>> getAll([Transaction? transaction]) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps =
        await db.query(tableName, orderBy: 'modified_date desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<QuoteLineGroup>> getByQuoteId(int quoteId,
      [Transaction? transaction]) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps = await db.query(tableName,
        where: 'quote_id = ?', whereArgs: [quoteId], orderBy: 'id desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<int> deleteByQuoteId(int quoteId, [Transaction? transaction]) async {
    final db = getDb(transaction);
    return db.delete(tableName, where: 'quote_id = ?', whereArgs: [quoteId]);
  }

  @override
  JuneStateCreator get juneRefresher => QuoteGroupLineState.new;
}

/// Used to notify the UI that the time entry has changed.
class QuoteGroupLineState extends JuneState {
  QuoteGroupLineState();
}
