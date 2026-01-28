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

import '../../entity/entity.dart';

abstract class DaoJoinAdaptor<C extends Entity<C>, P extends Entity<P>> {
  Future<List<C>> getByParent(P? parent);
  Future<void> insertForParent(C child, P parent, Transaction transaction);
  Future<void> deleteFromParent(C child, P parent);

  Future<void> setAsPrimary(C child, P parent);
}
