import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/check_list.dart';
import '../entity/check_list_item.dart';
import 'dao.dart';

class DaoCheckListItemCheckList extends Dao<CheckListItem> {
  Future<void> createTable(Database db, int version) async {}

  @override
  CheckListItem fromMap(Map<String, dynamic> map) => CheckListItem.fromMap(map);

  @override
  String get tableName => 'check_list_check_list_item';

  Future<void> deleteJoin(CheckList checklist, CheckListItem checklistitem,
      [Transaction? transaction]) async {
    await getDb(transaction).delete(
      tableName,
      where: 'check_list_id = ? and check_list_item_id = ?',
      whereArgs: [checklist.id, checklistitem.id],
    );
  }

  Future<void> insertJoin(CheckListItem checklistitem, CheckList checklist,
      [Transaction? transaction]) async {
    await getDb(transaction).insert(
      tableName,
      {'check_list_id': checklist.id, 'check_list_item_id': checklistitem.id},
    );
  }

  @override
  JuneStateCreator get juneRefresher => CheckListItemCheckListState.new;
}

/// Used to notify the UI that the time entry has changed.
class CheckListItemCheckListState extends JuneState {
  CheckListItemCheckListState();
}
