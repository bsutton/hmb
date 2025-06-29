/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:june/june.dart';
import 'package:strings/strings.dart';

import '../entity/task_item_type.dart';
import 'dao.dart';

class DaoTaskItemType extends Dao<TaskItemType> {
  @override
  String get tableName => 'task_item_type';

  /// Get all [TaskItemType]s
  Future<List<TaskItemType>> getAllTaskItemTypes() async {
    final db = withoutTransaction();
    return toList(await db.query(tableName));
  }

  /// Get [TaskItemType] by name
  Future<List<TaskItemType>> getByName(String name) async {
    final db = withoutTransaction();
    return toList(
      await db.query(tableName, where: 'name = ?', whereArgs: [name]),
    );
  }

  /// Get [TaskItemType] by 'toPurchase' flag
  Future<List<TaskItemType>> getByToPurchase({required bool toPurchase}) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'to_purchase = ?',
        whereArgs: [if (toPurchase) 1 else 0],
      ),
    );
  }

  Future<TaskItemType> getMaterialsBuy() async =>
      (await getByName('Materials - buy')).first;

  Future<TaskItemType> getMaterialsStock() async =>
      (await getByName('Materials - stock')).first;

  Future<TaskItemType> getToolsBuy() async =>
      (await getByName('Tools - buy')).first;

  Future<TaskItemType> getToolsOwn() async =>
      (await getByName('Tools - own')).first;

  Future<TaskItemType> getLabour() async => (await getByName('Labour')).first;

  /// Search for [TaskItemType]s based on a filter string
  Future<List<TaskItemType>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    if (Strings.isBlank(filter)) {
      return getAll();
    }

    final likeArg = '''%$filter%''';
    return toList(
      await db.rawQuery(
        '''
select it.*
from $tableName it
where it.name like ?
or it.description like ?
''',
        [likeArg, likeArg],
      ),
    );
  }

  @override
  TaskItemType fromMap(Map<String, dynamic> map) => TaskItemType.fromMap(map);

  @override
  JuneStateCreator get juneRefresher => TaskItemTypeState.new;
}

/// Used to notify the UI that the [TaskItemType] has changed.
class TaskItemTypeState extends JuneState {
  TaskItemTypeState();
}
