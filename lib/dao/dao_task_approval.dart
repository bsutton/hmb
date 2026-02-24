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

import '../entity/entity.g.dart';
import 'dao.g.dart';

class DaoTaskApproval extends Dao<TaskApproval> {
  static const tableName = 'task_approval';

  DaoTaskApproval() : super(tableName);

  @override
  TaskApproval fromMap(Map<String, dynamic> m) => TaskApproval.fromMap(m);

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    await DaoTaskApprovalTask().deleteByApproval(id, transaction: transaction);
    return db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TaskApproval>> getByJob(int jobId) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'created_date DESC',
    );
    return toList(rows);
  }

  Future<void> markSent(TaskApproval approval) async {
    approval.status = TaskApprovalStatus.sent;
    await update(approval);
  }
}
