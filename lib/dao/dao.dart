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

import 'package:scope/scope.dart';

import '../database/management/database_helper.dart';
import '../database/versions/db_upgrade.dart';
import '../entity/entity.dart';
import 'dao_base.dart';

export '../database/management/database_helper.dart';

abstract class Dao<T extends Entity<T>> extends DaoBase<T> {
  /// initialised with a default No Op notifier.
  /// main.dart should initialise this with DaoNotifier
  static void Function(DaoBase dao, [int? entityId]) notifier = (_, [_]) {};

  Dao(String tableName)
    : super(
        tableName,
        use(dbForUpgradeKey) ?? DatabaseHelper.instance.database,
        notifier,
      ) {
    super.mapper = fromMap;
  }

  // // Bridges DaoBase's `notifier` callback to our global hook.
  // static void _notifier(DaoBase dao, int? entityId) {
  //   DaoNotifications.notify(dao, entityId);
  // }

  T fromMap(Map<String, dynamic> map);

  T? getFirstOrNull(List<Map<String, Object?>> data) =>
      data.isNotEmpty ? fromMap(data.first) : null;
}
