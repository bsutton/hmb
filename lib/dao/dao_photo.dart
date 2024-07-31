import 'package:june/june.dart';

import '../entity/photo.dart';
import 'dao.dart';

class PhotoDao extends Dao<Photo> {
  Future<List<Photo>> getPhotosByTaskId(int taskId) async {
    final db = getDb();
    final List<Map<String, dynamic>> maps =
        await db.query('photos', where: 'taskId = ?', whereArgs: [taskId]);
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
