import 'package:sqflite_common/sqlite_api.dart';

import '../database/management/database_helper.dart';
import '../entity/entity.dart';

class DaoBase<T extends Entity<T>> {
  DaoBase(this._notify);

  /// Use this method when you need to do db operations
  /// from a non-flutter app - e.g. CLI apps.
  factory DaoBase.direct(
      String tableName, T Function(Map<String, dynamic> map) fromMap) {
    final dao = DaoBase<T>((_) {})
      .._tableName = tableName
      .._fromMap = fromMap;
    return dao;
  }

  final void Function(DaoBase<T> dao) _notify;

  late T Function(Map<String, dynamic> map) _fromMap;
  late String _tableName;

  // ignore: avoid_setters_without_getters
  set tableName(String tableName) => _tableName = tableName;

  // ignore: avoid_setters_without_getters
  set mapper(T Function(Map<String, dynamic> map) fromMap) =>
      _fromMap = fromMap;

  /// Insert [entity] into the database.
  /// Updating the passed in entity so that it has the assigned id.
  Future<int> insert(covariant T entity, [Transaction? transaction]) async {
    final db = getDb(transaction);
    entity
      ..createdDate = DateTime.now()
      ..modifiedDate = DateTime.now();
    final id = await db.insert(_tableName, entity.toMap()..remove('id'));
    entity.id = id;

    _notify(this);

    return id;
  }

  /// [orderByClause] is the list of columns followed by the collation order
  ///  ```name desc, age```
  Future<List<T>> getAll(
      {String? orderByClause, Transaction? transaction}) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps =
        await db.query(_tableName, orderBy: orderByClause);
    final list = List.generate(maps.length, (i) => _fromMap(maps[i]));

    return list;
  }

  Future<T?> getById(int? entityId) async {
    final db = getDb();

    if (entityId == null) {
      return null;
    }
    final value =
        await db.query(_tableName, where: 'id =?', whereArgs: [entityId]);
    if (value.isEmpty) {
      return null;
    }
    final entity = _fromMap(value.first);
    return entity;
  }

  Future<int> update(covariant T entity, [Transaction? transaction]) async {
    final db = getDb(transaction);
    entity.modifiedDate = DateTime.now();
    final id = await db.update(
      _tableName,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
    _notify(this);
    return id;
  }

  //// Returns the number of rows deleted.
  Future<int> delete(int id, [Transaction? transaction]) async {
    final db = getDb(transaction);
    final rowsDeleted = db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify(this);
    return rowsDeleted;
  }

  List<T> toList(List<Map<String, Object?>> data) {
    if (data.isEmpty) {
      return [];
    }
    return List.generate(data.length, (i) => _fromMap(data[i]));
  }

  DatabaseExecutor getDb([Transaction? transaction]) =>
      transaction ?? DatabaseHelper.instance.database;
}
