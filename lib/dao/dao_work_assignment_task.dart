// lib/src/dao/dao_work_assignment_task.dart

import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/entity.g.dart';
import 'dao.g.dart';

class DaoWorkAssignmentTask extends Dao<WorkAssignmentTask> {
  @override
  String get tableName => 'work_assignment_task';

  @override
  WorkAssignmentTask fromMap(Map<String, dynamic> m) =>
      WorkAssignmentTask.fromMap(m);

  Future<void> deleteByAssignment(
    int assignmentId, {
    Transaction? transaction,
  }) async {
    final db = withinTransaction(transaction);

    // 1️⃣ delete the tasks
    await db.delete(
      tableName,
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
    );
  }

  Future<List<WorkAssignmentTask>> getByAssignment(int assignmentId) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
    );
    return toList(rows);
  }

  /// Deletes all task links for a given task and marks
  /// each related work assignment as modified.
  Future<void> deleteByTask(
    int taskId, {
    Transaction? transaction,
  }) async => withTransaction((txn) async {
    // 1️⃣ fetch assignment IDs linked to this task
    final rows = await txn.query(
      tableName,
      columns: ['assignment_id'],
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    final assignmentIds = rows.map((m) => m['assignment_id']! as int).toSet();

    // 2️⃣ delete the task links
    await txn.delete(tableName, where: 'task_id = ?', whereArgs: [taskId]);

    // 3️⃣ mark each parent assignment as modified
    final now = DateTime.now().toIso8601String();
    for (final assignmentId in assignmentIds) {
      await txn.update(
        'work_assignment',
        {'status': WorkAssignmentStatus.modified.index, 'modified_date': now},
        where: 'id = ?',
        whereArgs: [assignmentId],
      );
    }
  });

  /// Get work assignments for the given task.
  Future<List<WorkAssignmentTask>> getByTask(Task task) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'task_id = ?',
      whereArgs: [task.id],
    );
    return toList(rows);
  }

  @override
  JuneStateCreator get juneRefresher => WorkAssignmentTaskState.new;
}

/// Used to notify the UI that the time entry has changed.
class WorkAssignmentTaskState extends JuneState {
  WorkAssignmentTaskState();
}
