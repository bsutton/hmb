import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/check_list.dart';
import '../entity/check_list_item.dart';
import 'dao.dart';
import 'dao_check_list_item_check_list.dart';

class DaoCheckListItem extends Dao<CheckListItem> {
  Future<void> createTable(Database db, int version) async {}

  @override
  CheckListItem fromMap(Map<String, dynamic> map) => CheckListItem.fromMap(map);

  @override
  String get tableName => 'check_list_item';

  Future<List<CheckListItem>> getByCheckList(CheckList checklist) async {
    final db = getDb();

    final data = await db.rawQuery('''
select cli.* 
from check_list cl
join check_list_item cli
  on cl.id = cli.check_list_id
where cl.id =? 
''', [checklist.id]);

    return toList(data);
  }

  Future<void> deleteFromCheckList(
      CheckListItem checklistitem, CheckList checklist) async {
    await DaoCheckListItemCheckList().deleteJoin(checklist, checklistitem);
    await delete(checklistitem.id);
  }

  Future<void> insertForCheckList(
      CheckListItem checklistitem, CheckList checklist) async {
    await insert(checklistitem);
    await DaoCheckListItemCheckList().insertJoin(checklistitem, checklist);
  }

  Future<void> markAsCompleted(CheckListItem item, Money cost) async {
    item
      ..cost = cost
      ..completed = true;

    await update(item);
  }

  Future<List<CheckListItem>> getIncompleteItems() async {
    final db = getDb();

    final data = await db.rawQuery('''
select cli.* 
from check_list_item cli
where cli.completed = 0
''');

    return toList(data);
  }

  Future<void> deleteByChecklist(CheckList checklist) async {
    final db = getDb();

    await db.rawDelete('''
delete cli.* 
from check_list_item cli
join check_list cl
  on cl.id = cli.check_list_id
where cl.id =? 
''', [checklist.id]);
  }

  @override
  JuneStateCreator get juneRefresher => CheckListItemState.new;
}

/// Used to notify the UI that the time entry has changed.
class CheckListItemState extends JuneState {
  CheckListItemState();
}
