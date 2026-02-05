/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 GPL terms per repo license.
*/

import 'package:sqflite_common/sqlite_api.dart';

import '../entity/photo_delete_queue.dart';
import 'dao.dart';

class DaoPhotoDeleteQueue extends Dao<PhotoDeleteQueue> {
  static const tableName = 'photo_delete_queue';

  DaoPhotoDeleteQueue() : super(tableName);

  @override
  PhotoDeleteQueue fromMap(Map<String, dynamic> map) =>
      PhotoDeleteQueue.fromMap(map);

  Future<void> enqueue(int photoId) async {
    final db = withoutTransaction();
    final entity = PhotoDeleteQueue.forInsert(photoId: photoId);
    await db.insert(
      tableName,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeByPhotoId(int photoId) async {
    final db = withoutTransaction();
    await db.delete(tableName, where: 'photo_id = ?', whereArgs: [photoId]);
  }

  /// Returns photo ids queued for deletion that no longer exist in the DB.
  Future<List<PhotoDeleteQueue>> getPendingDeleteIds() async {
    final db = withoutTransaction();
    final rows = await db.rawQuery('''
SELECT q.*
FROM $tableName q
LEFT JOIN photo p ON p.id = q.photo_id
WHERE p.id IS NULL
''');
    return toList(rows);
  }

  @override
  Future<int> delete(int id, [Transaction? transaction]) {
    final db = withinTransaction(transaction);
    return db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }
}
