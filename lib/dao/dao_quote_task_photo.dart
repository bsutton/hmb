/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:sqflite_common/sqlite_api.dart';

import '../entity/quote_task_photo.dart';
import 'dao.g.dart';

class DaoQuoteTaskPhoto extends Dao<QuoteTaskPhoto> {
  static const tableName = 'quote_task_photo';

  DaoQuoteTaskPhoto() : super(tableName);

  @override
  QuoteTaskPhoto fromMap(Map<String, dynamic> map) =>
      QuoteTaskPhoto.fromMap(map);

  Future<List<QuoteTaskPhoto>> getByQuote(
    int quoteId, {
    Transaction? transaction,
  }) async {
    final db = withinTransaction(transaction);
    final rows = await db.query(
      tableName,
      where: 'quote_id = ?',
      whereArgs: [quoteId],
      orderBy: 'task_id ASC, display_order ASC, id ASC',
    );
    return toList(rows);
  }

  Future<void> replaceByQuote(
    int quoteId,
    List<QuoteTaskPhoto> selections, {
    Transaction? transaction,
  }) async {
    if (transaction != null) {
      await _replaceByQuote(transaction, quoteId, selections);
      return;
    }

    await withTransaction((txn) => _replaceByQuote(txn, quoteId, selections));
  }

  Future<void> _replaceByQuote(
    Transaction txn,
    int quoteId,
    List<QuoteTaskPhoto> selections,
  ) async {
    await txn.delete(tableName, where: 'quote_id = ?', whereArgs: [quoteId]);
    for (final selection in selections) {
      await txn.insert(tableName, selection.toMap()..remove('id'));
    }
  }
}
