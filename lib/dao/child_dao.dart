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

import '../entity/entity.dart';

abstract class ChildDao<C extends Entity<C>, P extends Entity<P>> {
  /// delete the child owned by [parent]
  Future<void> delete(C child, P parent);

  /// insert the child owned by [parent]
  Future<void> insert(C child, P parent);
}
