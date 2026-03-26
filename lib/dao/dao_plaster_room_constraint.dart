/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:sqflite_common/sqlite_api.dart';

import '../entity/plaster_room_constraint.dart';
import 'dao.dart';

class DaoPlasterRoomConstraint extends Dao<PlasterRoomConstraint> {
  static const tableName = 'plaster_room_constraint';

  DaoPlasterRoomConstraint() : super(tableName);

  @override
  PlasterRoomConstraint fromMap(Map<String, dynamic> map) =>
      PlasterRoomConstraint.fromMap(map);

  Future<void> _ensureTableExists([DatabaseExecutor? executor]) async {
    final dbExecutor = executor ?? db;
    await dbExecutor.execute('''
CREATE TABLE IF NOT EXISTS $tableName (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  room_id INTEGER NOT NULL REFERENCES plaster_room(id) ON DELETE CASCADE,
  line_id INTEGER NOT NULL REFERENCES plaster_room_line(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  target_value INTEGER,
  created_date TEXT NOT NULL,
  modified_date TEXT NOT NULL
)''');
    await dbExecutor.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS plaster_room_constraint_room_line_type_idx
ON $tableName(room_id, line_id, type)''');
    await dbExecutor.execute('''
CREATE INDEX IF NOT EXISTS plaster_room_constraint_room_idx
ON $tableName(room_id, line_id, id)''');
  }

  Future<List<PlasterRoomConstraint>> getByRoom(int roomId) async {
    await _ensureTableExists();
    final rows = await withoutTransaction().query(
      tableName,
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'line_id ASC, id ASC',
    );
    return toList(rows);
  }

  Future<PlasterRoomConstraint?> getByLineAndType(
    int lineId,
    PlasterConstraintType type,
  ) async {
    await _ensureTableExists();
    final rows = await withoutTransaction().query(
      tableName,
      where: 'line_id = ? AND type = ?',
      whereArgs: [lineId, type.name],
      limit: 1,
    );
    return rows.isEmpty ? null : fromMap(rows.first);
  }

  @override
  Future<int> insert(
    covariant PlasterRoomConstraint entity, [
    Transaction? transaction,
  ]) async {
    await _ensureTableExists(transaction);
    return super.insert(entity, transaction);
  }

  @override
  Future<int> update(
    covariant PlasterRoomConstraint entity, [
    Transaction? transaction,
  ]) async {
    await _ensureTableExists(transaction);
    return super.update(entity, transaction);
  }

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    await _ensureTableExists(transaction);
    return super.delete(id, transaction);
  }
}
