import 'package:flutter/foundation.dart';
import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../database/management/database_helper.dart';
import '../entity/entity.dart';

export '../database/management/database_helper.dart';
export 'dao_customer.dart';

typedef JuneStateCreator = JuneState Function();

abstract class Dao<T extends Entity<T>> {
  /// Insert [entity] into the database.
  /// Updating the passed in entity so that it has the assigned id.
  Future<int> insert(covariant T entity, [Transaction? transaction]) async {
    final db = getDb(transaction);
    final id = await db.insert(tableName, entity.toMap()..remove('id'));
    entity.id = id;

    _notify();

    return id;
  }

  void _notify() {
    June.getState(juneRefresher).setState();
  }

  /// A callback which provides the [Dao]p with the ability to notify
  /// the [JuneState] returned by [juneRefresher].
  /// The [Dao] notifies the [juneRefresher] when ever the table
  /// is changed via one of the standard CRUD operations exposed
  /// by the Dao.
  JuneStateCreator get juneRefresher;

  Future<List<T>> getAll([Transaction? transaction]) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    final list = List.generate(maps.length, (i) => fromMap(maps[i]));

    return list;
  }

  Future<T?> getById(int? entityId) async {
    final db = getDb();
    final value =
        await db.query(tableName, where: 'id =?', whereArgs: [entityId]);
    if (value.isEmpty) {
      return null;
    }
    final entity = fromMap(value.first);
    return entity;
  }

  Future<int> update(covariant T entity, [Transaction? transaction]) async {
    final db = getDb(transaction);
    final id = await db.update(
      tableName,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
    _notify();
    return id;
  }

  //// Returns the number of rows deleted.
  Future<int> delete(int id, [Transaction? transaction]) async {
    final db = getDb(transaction);
    final rowsDeleted = db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify();
    return rowsDeleted;
  }

  @protected
  List<T> toList(List<Map<String, Object?>> data) {
    if (data.isEmpty) {
      return [];
    }
    return List.generate(data.length, (i) => fromMap(data[i]));
  }

  T fromMap(Map<String, dynamic> map);

  DatabaseExecutor getDb([Transaction? transaction]) =>
      transaction ?? DatabaseHelper.instance.database;

  String get tableName;
}
