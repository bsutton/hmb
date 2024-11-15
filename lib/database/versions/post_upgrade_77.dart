import 'package:sqflite_common/sqlite_api.dart';

import '../../dao/dao_base.dart';
import '../../entity/photo.dart';
import '../../util/photo_meta.dart';
import '../../widgets/media/captured_photo.dart';

/// Is run after the v77.sql upgrade script is run.
/// Converts all absolute paths in the db to relative paths.
Future<void> postv77Upgrade(Database db) async {
  final daoPhoto = DaoBase<Photo>.direct(db, 'photo', Photo.fromMap);
  final photos = await daoPhoto.getAll();

  for (final photo in photos) {
    final absolutePathToPhoto =
        await PhotoMeta.fromPhoto(photo: photo).resolve();
    photo.filePath = (await CapturedPhoto.fromAbsolute(
            absolutePathToPhoto: absolutePathToPhoto))
        .relativePath;

    await daoPhoto.update(photo);
  }
}
