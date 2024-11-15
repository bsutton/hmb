import 'package:june/june.dart';
import 'package:strings/strings.dart';

import '../entity/check_list_item_type.dart';
import 'dao.dart';

class DaoCheckListItemType extends Dao<CheckListItemType> {
  @override
  String get tableName => 'check_list_item_type';

  /// Get all CheckListItemTypes
  Future<List<CheckListItemType>> getAllCheckListItemTypes() async {
    final db = withoutTransaction();
    final data = await db.query(tableName);
    return toList(data);
  }

  /// Get CheckListItemTypes by name
  Future<List<CheckListItemType>> getByName(String name) async {
    final db = withoutTransaction();
    final data = await db.query(
      tableName,
      where: 'name = ?',
      whereArgs: [name],
    );
    return toList(data);
  }

  /// Get CheckListItemTypes by 'toPurchase' flag
  Future<List<CheckListItemType>> getByToPurchase(
      {required bool toPurchase}) async {
    final db = withoutTransaction();
    final data = await db.query(
      tableName,
      where: 'to_purchase = ?',
      whereArgs: [if (toPurchase) 1 else 0],
    );
    return toList(data);
  }

  Future<CheckListItemType> getMaterialsBuy() async =>
      (await getByName('Materials - buy')).first;

  Future<CheckListItemType> getMaterialsStock() async =>
      (await getByName('Materials - stock')).first;

  Future<CheckListItemType> getToolsBuy() async =>
      (await getByName('Tools - buy')).first;

  Future<CheckListItemType> getToolsOwn() async =>
      (await getByName('Tools - own')).first;

  Future<CheckListItemType> getLabour() async =>
      (await getByName('Labour')).first;

  /// Search for CheckListItemTypes based on a filter string
  Future<List<CheckListItemType>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    if (Strings.isBlank(filter)) {
      return getAll();
    }

    final likeArg = '''%$filter%''';
    final data = await db.rawQuery('''
select it.*
from check_list_item_type it
where it.name like ?
or it.description like ?
''', [likeArg, likeArg]);

    return toList(data);
  }

  @override
  CheckListItemType fromMap(Map<String, dynamic> map) =>
      CheckListItemType.fromMap(map);

  @override
  JuneStateCreator get juneRefresher => CheckListItemTypeState.new;
}

/// Used to notify the UI that the CheckListItemType has changed.
class CheckListItemTypeState extends JuneState {
  CheckListItemTypeState();
}
