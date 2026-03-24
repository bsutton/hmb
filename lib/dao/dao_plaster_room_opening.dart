/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import '../entity/plaster_room_opening.dart';
import 'dao.dart';

class DaoPlasterRoomOpening extends Dao<PlasterRoomOpening> {
  static const tableName = 'plaster_room_opening';

  DaoPlasterRoomOpening() : super(tableName);

  @override
  PlasterRoomOpening fromMap(Map<String, dynamic> map) =>
      PlasterRoomOpening.fromMap(map);

  Future<List<PlasterRoomOpening>> getByLineIds(List<int> lineIds) async {
    if (lineIds.isEmpty) {
      return [];
    }
    final placeholders = List.filled(lineIds.length, '?').join(',');
    final rows = await withoutTransaction().rawQuery(
      '''
SELECT *
FROM $tableName
WHERE line_id IN ($placeholders)
ORDER BY id ASC
''',
      lineIds,
    );
    return toList(rows);
  }
}
