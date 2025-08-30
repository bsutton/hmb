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

import '../../dao/dao_base.dart';
import '../../entity/photo.dart';
import '../../ui/widgets/media/captured_photo.dart';
import '../../util/dart/photo_meta.dart';

/// Is run after the v77.sql upgrade script is run.
/// Converts all absolute paths in the db to relative paths.
Future<void> postv77Upgrade(Database db) async {
  final daoPhoto = DaoBase<Photo>.direct(db, 'photo', Photo.fromMap);
  final photos = await daoPhoto.getAll();

  for (final photo in photos) {
    final absolutePathToPhoto = await PhotoMeta.fromPhoto(
      photo: photo,
    ).resolve();
    photo.filename = (await CapturedPhoto.fromAbsolute(
      absolutePathToPhoto: absolutePathToPhoto,
    )).filename;

    await daoPhoto.update(photo);
  }
}
