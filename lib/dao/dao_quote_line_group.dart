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

import '../entity/quote_line_group.dart';
import 'dao.dart';
import 'dao_task.dart';

class DaoQuoteLineGroup extends Dao<QuoteLineGroup> {
  static const tableName = 'quote_line_group';

  DaoQuoteLineGroup() : super(tableName);

  @override
  QuoteLineGroup fromMap(Map<String, dynamic> map) =>
      QuoteLineGroup.fromMap(map);

  @override
  Future<List<QuoteLineGroup>> getAll({
    String? orderByClause,
    Transaction? transaction,
  }) async {
    final db = withinTransaction(transaction);
    return toList(await db.query(tableName, orderBy: 'modified_date asc'));
  }

  Future<List<QuoteLineGroup>> getByQuoteId(
    int quoteId, [
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);
    return toList(
      await db.query(
        tableName,
        where: 'quote_id = ?',
        whereArgs: [quoteId],
        orderBy: 'id asc',
      ),
    );
  }

  Future<int> deleteByQuoteId(int quoteId, [Transaction? transaction]) {
    final db = withinTransaction(transaction);
    return db.delete(tableName, where: 'quote_id = ?', whereArgs: [quoteId]);
  }

  Future<void> markRejected(int quoteGroupLineId) async {
    final quoteGroupLine = await getById(quoteGroupLineId);

    quoteGroupLine!.lineApprovalStatus = LineApprovalStatus.rejected;

    await update(quoteGroupLine);

    if (quoteGroupLine.taskId != null) {
      await DaoTask().markRejected(quoteGroupLine.taskId!);
    }
  }
}
