/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 GPL terms per repo license.
*/

import 'package:sqflite_common/sqlite_api.dart';

import '../database/management/database_helper.dart';
import '../entity/image_cache_variant.dart';

class DaoImageCacheVariant {
  static const tableName = 'image_cache_variant';

  Database get _db => DatabaseHelper.instance.database;

  Future<ImageCacheVariant?> getByKey(
    int photoId,
    String variant, [
    Transaction? txn,
  ]) async {
    final db = txn ?? _db;
    final rows = await db.query(
      tableName,
      where: 'photo_id = ? AND variant = ?',
      whereArgs: [photoId, variant],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ImageCacheVariant.fromMap(rows.first);
  }

  Future<List<ImageCacheVariant>> getByPhotoId(
    int photoId, [
    Transaction? txn,
  ]) async {
    final db = txn ?? _db;
    final rows = await db.query(
      tableName,
      where: 'photo_id = ?',
      whereArgs: [photoId],
    );
    return rows.map(ImageCacheVariant.fromMap).toList();
  }

  Future<void> upsert(ImageCacheVariant row, [Transaction? txn]) async {
    final db = txn ?? _db;
    await db.insert(
      tableName,
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> touch(
    int photoId,
    String variant,
    int when, [
    Transaction? txn,
  ]) async {
    final db = txn ?? _db;
    await db.update(
      tableName,
      {'last_access': when},
      where: 'photo_id = ? AND variant = ?',
      whereArgs: [photoId, variant],
    );
  }

  Future<void> removeKey(
    int photoId,
    String variant, [
    Transaction? txn,
  ]) async {
    final db = txn ?? _db;
    await db.delete(
      tableName,
      where: 'photo_id = ? AND variant = ?',
      whereArgs: [photoId, variant],
    );
  }

  Future<void> removeMissingSince(int resyncStartMs, Transaction txn) async {
    await txn.execute(
      '''
DELETE FROM $tableName
WHERE last_access <= ?
  AND NOT EXISTS (
    SELECT 1
    FROM image_cache_variant_seen s
    WHERE s.photo_id = $tableName.photo_id
      AND s.variant = $tableName.variant
  )
''',
      [resyncStartMs],
    );
  }

  Future<int> totalBytes([Transaction? txn]) async {
    final db = txn ?? _db;
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(size), 0) AS total FROM $tableName',
    );
    return (res.first['total'] as int?) ?? 0;
  }

  Future<ImageCacheVariant?> oldest([Transaction? txn]) async {
    final db = txn ?? _db;
    final rows = await db.query(
      tableName,
      orderBy: 'last_access ASC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ImageCacheVariant.fromMap(rows.first);
  }
}
