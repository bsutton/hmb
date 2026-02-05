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

import '../../../cache/hmb_image_cache.dart';

/// Is run after the v142.sql upgrade script is run.
/// Rebuilds the cache table from any variants that already exist on disk.
Future<void> postv142Upgrade(Database db) async {
  await HMBImageCache.migrateDiskCacheToDatabase(db);
}
