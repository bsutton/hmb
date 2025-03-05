import 'package:sqflite_common/sqlite_api.dart';

import '../entity/entity.dart';

class DaoBase<T extends Entity<T>> {
  DaoBase(this.db, this._notify);

  /// Use this method when you need to do db operations
  /// from a non-flutter app - e.g. CLI apps.
  factory DaoBase.direct(
    Database db,
    String tableName,
    T Function(Map<String, dynamic> map) fromMap,
  ) {
    final dao =
        DaoBase<T>(db, (_, _) {})
          .._tableName = tableName
          .._fromMap = fromMap;
    return dao;
  }

  Database db;

  final void Function(DaoBase<T> dao, int? entityId) _notify;

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
    final executor = transaction ?? db;
    entity
      ..createdDate = DateTime.now()
      ..modifiedDate = DateTime.now();
    final id = await executor.insert(_tableName, entity.toMap()..remove('id'));
    entity.id = id;

    _notify(this, id);

    return id;
  }

  /// [orderByClause] is the list of columns followed by the collation order
  ///  ```name desc, age```
  Future<List<T>> getAll({String? orderByClause}) async {
    final executor = db;
    return toList(await executor.query(_tableName, orderBy: orderByClause));
  }

  Future<T?> getById(int? entityId) async {
    if (entityId == null) {
      return null;
    }
    final value = await db.query(
      _tableName,
      where: 'id =?',
      whereArgs: [entityId],
    );
    if (value.isEmpty) {
      return null;
    }
    final entity = _fromMap(value.first);
    return entity;
  }

  Future<int> update(covariant T entity, [Transaction? transaction]) async {
    final executor = transaction ?? db;
    entity.modifiedDate = DateTime.now();
    final id = await executor.update(
      _tableName,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
    _notify(this, id);
    return id;
  }

  //// Returns the number of rows deleted.
  Future<int> delete(int id, [Transaction? transaction]) async {
    final executor = transaction ?? db;
    final rowsDeleted = executor.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify(this, id);
    return rowsDeleted;
  }

  List<T> toList(List<Map<String, Object?>> data) {
    if (data.isEmpty) {
      return [];
    }
    return List.generate(data.length, (i) => _fromMap(data[i]));
  }

  /// Allows you to execute a command against the db
  /// optionally within a transaction.
  DatabaseExecutor withinTransaction(Transaction? transaction) =>
      transaction ?? db;

  DatabaseExecutor withoutTransaction() => db;
}
