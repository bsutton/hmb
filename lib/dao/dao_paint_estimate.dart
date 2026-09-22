import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../util/dart/paint_estimate.dart';
import 'dao_plaster_room.dart';

class DaoPaintEstimate {
  Future<PaintSettings> get(int roomId) async {
    final rows = await DaoPlasterRoom().withoutTransaction().query(
      'paint_room_estimate',
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
    if (rows.isEmpty) {
      return PaintSettings();
    }
    return PaintSettings.fromMap(
      jsonDecode(rows.single['settings_json']! as String)
          as Map<String, dynamic>,
    );
  }

  Future<void> save(int roomId, PaintSettings settings) async {
    settings.validate();
    await DaoPlasterRoom().withoutTransaction().insert('paint_room_estimate', {
      'room_id': roomId,
      'settings_json': jsonEncode(settings.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
