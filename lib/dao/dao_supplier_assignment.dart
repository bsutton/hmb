// lib/src/dao/dao_supplier_assignment.dart

import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/entity.g.dart';
import 'dao.g.dart';

class DaoSupplierAssignment extends Dao<SupplierAssignment> {
  @override
  String get tableName => 'supplier_assignment';

  @override
  SupplierAssignment fromMap(Map<String, dynamic> m) =>
      SupplierAssignment.fromMap(m);

  /// delete children then the assignment
  @override
  Future<int> delete(int id, [Transaction? txn]) async {
    final db = withinTransaction(txn);
    await DaoSupplierAssignmentTask().deleteByAssignment(id, transaction: txn);
    return db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SupplierAssignment>> getByJob(int jobId) async {
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
  JuneStateCreator get juneRefresher => SupplierAssignmentState.new;

  Future<void> markSent(SupplierAssignment assignment) async {
    assignment.sent = true;
    await update(assignment);
  }
}

/// Used to notify the UI that the time entry has changed.
class SupplierAssignmentState extends JuneState {
  SupplierAssignmentState();
}
