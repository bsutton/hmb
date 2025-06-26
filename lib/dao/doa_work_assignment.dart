// lib/src/dao/dao_work_assignment_task.dart

import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/task.dart';
import '../entity/work_assignment_task.dart';
import 'dao.g.dart';

class DoaWorkAssignment extends Dao<WorkAssignmentTask> {
  @override
  String get tableName => 'work_assignment_task';

  @override
  WorkAssignmentTask fromMap(Map<String, dynamic> m) =>
      WorkAssignmentTask.fromMap(m);

  Future<void> deleteByAssignment(
    int assignmentId, {
    Transaction? transaction,
  }) => withinTransaction(
    transaction,
  ).delete(tableName, where: 'assignment_id = ?', whereArgs: [assignmentId]);

  Future<List<WorkAssignmentTask>> getByAssignment(int assignmentId) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
    );
    return toList(rows);
  }

  @override
  JuneStateCreator get juneRefresher => WorkAssignmentTaskState.new;

  Future<void> deleteByTask(int taskId, {Transaction? transaction}) =>
      withinTransaction(
        transaction,
      ).delete(tableName, where: 'task_id = ?', whereArgs: [taskId]);

  Future<List<WorkAssignmentTask>> getByTask(Task task) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'task_id = ?',
      whereArgs: [task.id],
    );
    return toList(rows);
  }
}

/// Used to notify the UI that the time entry has changed.
class WorkAssignmentTaskState extends JuneState {
  WorkAssignmentTaskState();
}
