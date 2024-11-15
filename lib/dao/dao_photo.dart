import 'package:june/june.dart';
import 'package:path/path.dart';

import '../../../../util/paths.dart'
    if (dart.library.ui) '../../../../util/paths_flutter.dart';
import '../entity/photo.dart';
import 'dao.dart';
import 'dao_task.dart';
import 'dao_tool.dart';

enum ParentType { task, tool }

class DaoPhoto extends Dao<Photo> {
  Future<List<Photo>> getByParent(int parentId, ParentType parentType) async {
    final db = withoutTransaction();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'parentId = ? AND parentType = ?',
      whereArgs: [parentId, parentType.name],
    );
    return List.generate(maps.length, (i) => Photo.fromMap(maps[i]));
  }

  Future<List<String>> getAllPhotoPaths() async {
    final db = withoutTransaction();
    final List<Map<String, dynamic>> maps =
        await db.query('photo', columns: ['filePath']);
    return maps.map((map) => map['filePath'] as String).toList();
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

  PhotoMeta.fromPhoto({required this.photo})
      : comment = photo.comment,
        title = '';

  final Photo photo;
  final String title;
  String? comment;
  String? _absolutePath;

  static Future<List<PhotoMeta>> getByParent(
      int parentId, ParentType parentType) async {
    switch (parentType) {
      case ParentType.task:
        return getByJob(parentId);
      case ParentType.tool:
        return getByTool(parentId);
    }
  }

  String get absolutePathTo {
    assert(_absolutePath != null, 'You must call the resolve method first');

    return _absolutePath!;
  }

  Future<String> resolve() async =>
      _absolutePath = join(await getPhotosRootPath(), photo.filePath);

  static Future<List<PhotoMeta>> getByJob(int jobId) async {
    final tasks = await DaoTask().getTasksByJob(jobId);
    final photos = <PhotoMeta>[];
    for (final task in tasks) {
      final taskPhotos = await DaoPhoto().getByParent(task.id, ParentType.task);
      photos.addAll(taskPhotos.map(
          (photo) => PhotoMeta(photo: photo, title: task.name, comment: null)));
    }
    return photos;
  }

  static Future<List<PhotoMeta>> getByTool(int toolId) async {
    final tool = await DaoTool().getById(toolId);
    return (await DaoPhoto().getByParent(tool!.id, ParentType.tool))
        .map((photo) => PhotoMeta(
            photo: photo, title: tool.name, comment: tool.description))
        .toList();
  }

  /// Resolves all of the file paths into absolute file paths.
  static Future<List<PhotoMeta>> resolveAll(List<PhotoMeta> photos) async {
    for (final meta in photos) {
      await meta.resolve();
    }
    return photos;
  }
}
