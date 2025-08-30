/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import '../database/management/backup_providers/google_drive/background_backup/photo_sync_params.dart';
import '../entity/photo.dart';
import '../util/dart/format.dart';
import '../util/dart/photo_meta.dart';
import 'dao.g.dart';

class DaoPhoto extends Dao<Photo> {
  static const tableName = 'photo';
  DaoPhoto() : super(tableName);

  Future<List<Photo>> getByParent(int parentId, ParentType parentType) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'parentId = ? AND parentType = ?',
        whereArgs: [parentId, parentType.name],
      ),
    );
  }

  Future<List<String>> getAllPhotoFileNames() async {
    final db = withoutTransaction();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      columns: ['fileName'],
    );
    return maps.map((map) => map['fileName'] as String).toList();
  }

  /// Returns the list of photos that have not been backed up yet.
  Future<List<PhotoPayload>> getUnsyncedPhotos() async {
    final db = withoutTransaction();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'last_backup_date IS NULL',
    );

    final payloads = <PhotoPayload>[];
    for (final photo in toList(maps)) {
      payloads.add(await PhotoPayload.fromPhoto(photo));
    }
    return payloads;
  }

  /// Updates the photo record to mark it as backed up.
  Future<void> updatePhotoSyncStatus(int photoId) async {
    final db = withoutTransaction();
    await db.rawUpdate(
      'UPDATE photo '
      "SET last_backup_date = datetime('now') "
      'WHERE id = ?',
      [photoId],
    );
  }

  @override
  Photo fromMap(Map<String, dynamic> map) => Photo.fromMap(map);

  static Future<List<PhotoMeta>> getByTask(int taskId) async {
    final task = await DaoTask().getById(taskId);
    final photos = <PhotoMeta>[];
    final taskPhotos = await DaoPhoto().getByParent(task!.id, ParentType.task);
    photos.addAll(
      taskPhotos.map(
        (photo) => PhotoMeta(photo: photo, title: task.name, comment: null),
      ),
    );
    return photos;
  }

  static Future<List<PhotoMeta>> getByTool(int toolId) async {
    final tool = await DaoTool().getById(toolId);
    return (await DaoPhoto().getByParent(tool!.id, ParentType.tool))
        .map(
          (photo) => PhotoMeta(
            photo: photo,
            title: tool.name,
            comment: tool.description,
          ),
        )
        .toList();
  }

  static Future<List<PhotoMeta>> getByReceipt(int receiptId) async {
    final receipt = await DaoReceipt().getById(receiptId);
    final supplier = await DaoSupplier().getById(receipt!.supplierId);

    return (await DaoPhoto().getByParent(receiptId, ParentType.receipt))
        .map(
          (photo) => PhotoMeta(
            photo: photo,
            title: '${supplier!.name} ${formatDate(receipt.receiptDate)}',
            comment: '',
          ),
        )
        .toList();
  }

  static Future<List<PhotoMeta>> getMetaByParent(
    int parentId,
    ParentType parentType,
  ) {
    switch (parentType) {
      case ParentType.task:
        return getByTask(parentId);
      case ParentType.tool:
        return getByTool(parentId);
      case ParentType.receipt:
        return getByReceipt(parentId);
    }
  }
}
