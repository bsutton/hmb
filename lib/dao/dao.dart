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


import 'package:june/june.dart';

import '../database/management/database_helper.dart';
import '../entity/entity.dart';
import 'dao_base.dart';

export '../database/management/database_helper.dart';

typedef JuneStateCreator = JuneState Function();

abstract class Dao<T extends Entity<T>> extends DaoBase<T> {
  Dao() : super(DatabaseHelper.instance.database, _notifier) {
    super.tableName = tableName;
    super.mapper = fromMap;
  }

  static void _notifier(DaoBase dao, int? entityId) {
    (dao as Dao)._notify(entityId);
  }

  void _notify(int? entityId) {
    June.getState(juneRefresher).setState([if (entityId != null) entityId]);
  }

  /// A callback which provides the [Dao]p with the ability to notify
  /// the [JuneState] returned by [juneRefresher].
  /// The [Dao] notifies the [juneRefresher] when ever the table
  /// is changed via one of the standard CRUD operations exposed
  /// by the Dao.
  JuneStateCreator get juneRefresher;

  T fromMap(Map<String, dynamic> map);

  T? getFirstOrNull(List<Map<String, Object?>> data) =>
      data.isNotEmpty ? fromMap(data.first) : null;

  String get tableName;
}
