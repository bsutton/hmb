// lib/src/dao/dao_work_assignment.dart

import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/entity.g.dart';
import 'dao.g.dart';

class DaoWorkAssigment extends Dao<WorkAssignment> {
  @override
  String get tableName => 'work_assignment';

  @override
  WorkAssignment fromMap(Map<String, dynamic> m) => WorkAssignment.fromMap(m);

  /// delete children then the assignment
  @override
  Future<int> delete(int id, [Transaction? txn]) async {
    final db = withinTransaction(txn);
    await DaoWorkAssignmentTask().deleteByAssignment(id, transaction: txn);
    return db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkAssignment>> getByJob(int jobId) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'created_date DESC',
    );
    return toList(rows);
  }

  @override
  JuneStateCreator get juneRefresher => WorkAssignmentState.new;

  Future<void> markSent(WorkAssignment assignment) async {
    assignment.status = WorkAssignmentStatus.sent;
    await update(assignment);
  }
}

/// Used to notify the UI that the time entry has changed.
class WorkAssignmentState extends JuneState {
  WorkAssignmentState();
}
