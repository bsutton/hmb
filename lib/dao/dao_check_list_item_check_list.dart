/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:sqflite_common/sqlite_api.dart';

import '../entity/check_list.dart';
import '../entity/check_list_item.dart';
import 'dao.dart';

class DaoCheckListItemCheckList extends Dao<CheckListItem> {
  static const tableName = 'check_list_check_list_item';
  DaoCheckListItemCheckList() : super(tableName);

  Future<void> createTable(Database db, int version) async {}

  @override
  CheckListItem fromMap(Map<String, dynamic> map) => CheckListItem.fromMap(map);

  Future<void> deleteJoin(
    CheckList checklist,
    CheckListItem checklistitem, [
    Transaction? transaction,
  ]) async {
    await withinTransaction(transaction).delete(
      tableName,
      where: 'check_list_id = ? and check_list_item_id = ?',
      whereArgs: [checklist.id, checklistitem.id],
    );
  }

  Future<void> insertJoin(
    CheckListItem checklistitem,
    CheckList checklist, [
    Transaction? transaction,
  ]) async {
    await withinTransaction(transaction).insert(tableName, {
      'check_list_id': checklist.id,
      'check_list_item_id': checklistitem.id,
    });
  }
}
