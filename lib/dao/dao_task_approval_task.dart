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

class DaoTaskApprovalTask extends Dao<TaskApprovalTask> {
  static const tableName = 'task_approval_task';

  DaoTaskApprovalTask() : super(tableName);

  @override
  TaskApprovalTask fromMap(Map<String, dynamic> m) =>
      TaskApprovalTask.fromMap(m);

  Future<void> deleteByApproval(
    int approvalId, {
    Transaction? transaction,
  }) async {
    final db = withinTransaction(transaction);
    await db.delete(
      tableName,
      where: 'approval_id = ?',
      whereArgs: [approvalId],
    );
  }

  Future<List<TaskApprovalTask>> getByApproval(int approvalId) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'approval_id = ?',
      whereArgs: [approvalId],
    );
    return toList(rows);
  }

  Future<List<TaskApprovalTask>> getByTask(Task task) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'task_id = ?',
      whereArgs: [task.id],
    );
    return toList(rows);
  }

  Future<void> updateDecision({
    required TaskApprovalTask approvalTask,
    required TaskApprovalDecision decision,
  }) async {
    await update(approvalTask.copyWith(status: decision));
  }
}
