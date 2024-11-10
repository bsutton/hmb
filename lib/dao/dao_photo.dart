import 'package:june/june.dart';

import '../entity/photo.dart';
import 'dao.dart';
import 'dao_task.dart';
import 'dao_tool.dart';

enum ParentType { task, tool }

class DaoPhoto extends Dao<Photo> {
  Future<List<Photo>> getByParent(int parentId, ParentType parentType) async {
    final db = getDb();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'parentId = ? AND parentType = ?',
      whereArgs: [parentId, parentType.name],
    );
    return List.generate(maps.length, (i) => Photo.fromMap(maps[i]));
  }

  @override
  Photo fromMap(Map<String, dynamic> map) => Photo.fromMap(map);

  @override
  JuneStateCreator get juneRefresher => PhotoState.new;

  @override
  String get tableName => 'photo';
}

class PhotoState extends JuneState {
  PhotoState();
}

class PhotoMeta {
  PhotoMeta({required this.photo, required this.title, required this.comment});
  Photo photo;
  String title;
  String? comment;

  static Future<List<PhotoMeta>> getByParent(
      int parentId, ParentType parentType) async {
    switch (parentType) {
      case ParentType.task:
        return getByJob(parentId);
      case ParentType.tool:
        return getByTool(parentId);
    }
  }
}

Future<List<PhotoMeta>> getByJob(int jobId) async {
  final tasks = await DaoTask().getTasksByJob(jobId);
  final photos = <PhotoMeta>[];
  for (final task in tasks) {
    final taskPhotos = await DaoPhoto().getByParent(task.id, ParentType.task);
    photos.addAll(taskPhotos.map(
        (photo) => PhotoMeta(photo: photo, title: task.name, comment: null)));
  }
  return photos;
}

Future<List<PhotoMeta>> getByTool(int toolId) async {
  final tool = await DaoTool().getById(toolId);
  return (await DaoPhoto().getByParent(tool!.id, ParentType.tool))
      .map((photo) =>
          PhotoMeta(photo: photo, title: tool.name, comment: tool.description))
      .toList();
}
