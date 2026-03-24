/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import '../entity/plaster_room.dart';
import 'dao.dart';

class DaoPlasterRoom extends Dao<PlasterRoom> {
  static const tableName = 'plaster_room';

  DaoPlasterRoom() : super(tableName);

  @override
  PlasterRoom fromMap(Map<String, dynamic> map) => PlasterRoom.fromMap(map);

  Future<List<PlasterRoom>> getByProject(int projectId) async {
    final rows = await withoutTransaction().query(
      tableName,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'id ASC',
    );
    return toList(rows);
  }
}
