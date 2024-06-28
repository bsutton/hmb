import 'package:june/june.dart';
import 'package:strings/strings.dart';

import '../entity/check_list_item_type.dart';
import 'dao.dart';

class DaoCheckListItemType extends Dao<CheckListItemType> {
  @override
  String get tableName => 'check_list_item_type';

  /// search for jobs given a user supplied filter string.
  Future<List<CheckListItemType>> getByFilter(String? filter) async {
    final db = getDb();

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

/// Used to notify the UI that the time entry has changed.
class CheckListItemTypeState extends JuneState {
  CheckListItemTypeState();
}
