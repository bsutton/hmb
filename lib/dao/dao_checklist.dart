import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/check_list.dart';
import '../entity/task.dart';
import 'dao.dart';
import 'dao_check_list_task.dart';

class DaoCheckList extends Dao<CheckList> {
  Future<void> createTable(Database db, int version) async {}

  @override
  CheckList fromMap(Map<String, dynamic> map) => CheckList.fromMap(map);

  @override
  String get tableName => 'check_list';

  Future<CheckList?> getByTask(int? taskId) async {
    final db = getDb();

    if (taskId == null) {
      return null;
    }
    final data = await db.rawQuery('''
select cl.* 
from check_list cl
join task_check_list jc
  on cl.id = jc.check_list_id
join task jo
  on jc.task_id = jo.id
where jo.id =? 
''', [taskId]);

    final list = toList(data);

    if (list.isEmpty) {
      return null;
    }

    assert(list.length == 1, 'A task should only have one default checklist');
    return list.first;
  }

  Future<void> deleteFromTask(CheckList checklist, Task task) async {
    await DaoCheckListTask().deleteJoin(task, checklist);
    await delete(checklist.id);
  }

  Future<void> insertForTask(CheckList checklist, Task task) async {
    await insert(checklist);
    await DaoCheckListTask().insertJoin(checklist, task);
  }

  @override
  JuneStateCreator get juneRefresher => CheckListState.new;
}

/// Used to notify the UI that the time entry has changed.
class CheckListState extends JuneState {
  CheckListState();
}
