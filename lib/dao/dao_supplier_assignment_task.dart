// lib/src/dao/dao_supplier_assignment_task.dart

import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/supplier_assignment_task.dart';
import 'dao.g.dart';

class DaoSupplierAssignmentTask extends Dao<SupplierAssignmentTask> {
  @override
  String get tableName => 'supplier_assignment_task';

  @override
  SupplierAssignmentTask fromMap(Map<String, dynamic> m) =>
      SupplierAssignmentTask.fromMap(m);

  Future<void> deleteByAssignment(
    int assignmentId, {
    Transaction? transaction,
  }) => withinTransaction(
    transaction,
  ).delete(tableName, where: 'assignment_id = ?', whereArgs: [assignmentId]);

  Future<List<SupplierAssignmentTask>> getByAssignment(int assignmentId) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
    );
    return toList(rows);
  }

  @override
  JuneStateCreator get juneRefresher =>  SupplierAssignmentTaskState.new;
}

/// Used to notify the UI that the time entry has changed.
class SupplierAssignmentTaskState extends JuneState {
  SupplierAssignmentTaskState();
}
