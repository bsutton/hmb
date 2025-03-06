import 'package:june/june.dart';

import '../entity/photo.dart';
import '../util/photo_meta.dart';
import 'dao.dart';
import 'dao_task.dart';
import 'dao_tool.dart';

enum ParentType { task, tool }

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
      'photo',
      columns: ['filePath'],
    );
    return maps.map((map) => map['filePath'] as String).toList();
  }

  /// Returns the list of photos that have not been backed up yet.
  Future<List<Photo>> getNewPhotos() async {
    // You can add a query method to DaoPhoto that returns only photos with a null last_backup_date.
    final db = withoutTransaction();
    final List<Map<String, dynamic>> maps = await db.query(
      'photo',
      where: 'last_backup_date IS NULL',
    );
    return maps.map(Photo.fromMap).toList();
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

  static Future<List<PhotoMeta>> getMetaByParent(
    int parentId,
    ParentType parentType,
  ) async {
    switch (parentType) {
      case ParentType.task:
        return getByTask(parentId);
      case ParentType.tool:
        return getByTool(parentId);
    }
  }
}

class PhotoState extends JuneState {
  PhotoState();
}
