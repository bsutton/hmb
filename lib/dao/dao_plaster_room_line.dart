/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import '../entity/plaster_room_line.dart';
import 'dao.dart';

class DaoPlasterRoomLine extends Dao<PlasterRoomLine> {
  static const tableName = 'plaster_room_line';

  DaoPlasterRoomLine() : super(tableName);

  @override
  PlasterRoomLine fromMap(Map<String, dynamic> map) =>
      PlasterRoomLine.fromMap(map);

  Future<List<PlasterRoomLine>> getByRoom(int roomId) async {
    final rows = await withoutTransaction().query(
      tableName,
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'seq_no ASC',
    );
    return toList(rows);
  }
}
