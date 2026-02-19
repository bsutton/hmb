/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 GPL terms per repo license.
*/

import 'package:sqflite_common/sqlite_api.dart';

import '../entity/image_cache_variant.dart';
import 'dao.dart';

class DaoImageCacheVariant extends Dao<ImageCacheVariant> {
  static const tableName = 'image_cache_variant';

  DaoImageCacheVariant() : super(tableName);

  Future<ImageCacheVariant?> getByKey(
    int photoId,
    String variant, [
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);
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
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);
    final rows = await db.query(
      tableName,
      where: 'photo_id = ?',
      whereArgs: [photoId],
    );
    return rows.map(ImageCacheVariant.fromMap).toList();
  }

  Future<void> upsert(ImageCacheVariant row, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    await db.insert(
      tableName,
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  ImageCacheVariant fromMap(Map<String, dynamic> map) =>
      ImageCacheVariant.fromMap(map);

  Future<void> touch(
    int photoId,
    String variant,
    int when, [
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);
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
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);
    await db.delete(
      tableName,
      where: 'photo_id = ? AND variant = ?',
      whereArgs: [photoId, variant],
    );
  }

  Future<void> removeMissingSince(
    int resyncStartMs,
    Transaction transaction,
  ) async {
    await transaction.execute(
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

  Future<int> totalBytes([Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(size), 0) AS total FROM $tableName',
    );
    return (res.first['total'] as int?) ?? 0;
  }

  Future<int> totalPhotos([Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    final res = await db.rawQuery(
      'SELECT COUNT(DISTINCT photo_id) AS total FROM $tableName',
    );
    return (res.first['total'] as int?) ?? 0;
  }

  Future<ImageCacheVariant?> oldest([Transaction? transaction]) async {
    final db = withinTransaction(transaction);
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

  /// Returns the oldest cache entry whose photo has been backed up.
  Future<ImageCacheVariant?> oldestBackedUp([Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    final rows = await db.rawQuery('''
SELECT icv.*
  FROM $tableName icv
  JOIN photo p
    ON p.id = icv.photo_id
 WHERE p.last_backup_date IS NOT NULL
 ORDER BY icv.last_access ASC
 LIMIT 1
''');
    if (rows.isEmpty) {
      return null;
    }
    return ImageCacheVariant.fromMap(rows.first);
  }

  /// Returns up to [limit] oldest cache entries whose photos are backed up.
  Future<List<ImageCacheVariant>> oldestBackedUpBatch(
    int limit, [
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);
    final rows = await db.rawQuery(
      '''
SELECT icv.*
  FROM $tableName icv
  JOIN photo p
    ON p.id = icv.photo_id
 WHERE p.last_backup_date IS NOT NULL
 ORDER BY icv.last_access ASC
 LIMIT ?
''',
      [limit],
    );
    return rows.map(ImageCacheVariant.fromMap).toList();
  }
}
