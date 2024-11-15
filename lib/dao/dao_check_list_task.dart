import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/check_list.dart';
import '../entity/task.dart';
import 'dao.dart';

class DaoCheckListTask extends Dao<CheckList> {
  Future<void> createTable(Database db, int version) async {}

  @override
  CheckList fromMap(Map<String, dynamic> map) => CheckList.fromMap(map);

  @override
  String get tableName => 'task_check_list';

  Future<void> deleteJoin(int? taskId, CheckList checklist,
      [Transaction? transaction]) async {
    await withinTransaction(transaction).delete(
      tableName,
      where: 'task_id = ? and check_list_id = ?',
      whereArgs: [taskId, checklist.id],
    );
  }

  Future<void> insertJoin(CheckList checklist, Task task,
      [Transaction? transaction]) async {
    await withinTransaction(transaction).insert(
      tableName,
      {'task_id': task.id, 'check_list_id': checklist.id},
    );
  }

  Future<void> setAsPrimary(CheckList checklist, Task task,
      [Transaction? transaction]) async {
    await withinTransaction(transaction).update(
      tableName,
      {'primary': 1},
      where: 'task_id = ? and check_list_id = ?',
      whereArgs: [task.id, checklist.id],
    );
  }

  @override
  JuneStateCreator get juneRefresher => CheckListTaskState.new;
}

/// Used to notify the UI that the time entry has changed.
class CheckListTaskState extends JuneState {
  CheckListTaskState();
}
