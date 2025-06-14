import 'package:june/june.dart';

import '../database/management/backup_providers/google_drive/background_backup/photo_sync_params.dart';
import '../entity/photo.dart';
import '../util/util.g.dart';
import 'dao.g.dart';



class DaoPhoto extends Dao<Photo> {
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

  Future<List<String>> getAllPhotoPaths() async {
    final db = withoutTransaction();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      columns: ['filePath'],
    );
    return maps.map((map) => map['filePath'] as String).toList();
  }

  /// Returns the list of photos that have not been backed up yet.
  Future<List<PhotoPayload>> getUnsyncedPhotos() async {
    // You can add a query method to DaoPhoto that returns only photos with a null last_backup_date.
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
  Future<void> updatePhotoBackupStatus(int photoId) async {
    final db = withoutTransaction();
    // Raw SQL update statement:
    await db.rawUpdate(
      "UPDATE photo SET last_backup_date = datetime('now') WHERE id = ?",
      [photoId],
    );
  }

  @override
  Photo fromMap(Map<String, dynamic> map) => Photo.fromMap(map);

  @override
  JuneStateCreator get juneRefresher => PhotoState.new;

  @override
  String get tableName => 'photo';

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

class PhotoState extends JuneState {
  PhotoState();
}
