/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:sqflite_common/sqlite_api.dart';

import '../entity/entity.dart';
import '../util//dart/exceptions.dart' as hmb;

class DaoBase<T extends Entity<T>> {
  Database db;

  final void Function(DaoBase<T> dao, [int? entityId]) _notify;

  late T Function(Map<String, dynamic> map) _fromMap;
  late final String tablename;

  DaoBase(this.tablename, this.db, this._notify);

  /// Use this method when you need to do db operations
  /// from a non-flutter app - e.g. CLI apps.
  factory DaoBase.direct(
    Database db,
    String tableName,
    T Function(Map<String, dynamic> map) fromMap,
  ) {
    final dao = DaoBase<T>(tableName, db, (_, [_]) {}).._fromMap = fromMap;
    dao._notify(dao);
    return dao;
  }

  // ignore: avoid_setters_without_getters
  set mapper(T Function(Map<String, dynamic> map) fromMap) =>
      _fromMap = fromMap;

  /// Insert [entity] into the database.
  /// Updating the passed in entity so that it has the assigned id.
  Future<int> insert(covariant T entity, [Transaction? transaction]) async {
    final executor = transaction ?? db;
    final id = await executor.insert(tablename, entity.toMap()..remove('id'));
    if (id == 0) {
      // the insert faield.
      throw hmb.DatabaseException('Insert for $T failed');
    }
    entity.id = id;

    _notify(this, id);

    return id;
  }

  /// [orderByClause] is the list of columns followed by the collation order
  ///  ```name desc, age```
  Future<List<T>> getAll({String? orderByClause}) async {
    final executor = db;
    return toList(await executor.query(tablename, orderBy: orderByClause));
  }

  Future<T?> getById(int? entityId, [Transaction? transaction]) async {
    if (entityId == null) {
      return null;
    }
    final executor = transaction ?? db;
    final value = await executor.query(
      tablename,
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
    final count = await executor.update(
      tablename,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
    assert(count == 1, 'We should always be only updating one entity');
    _notify(this, entity.id);
    return entity.id;
  }

  //// Returns the number of rows deleted.
  Future<int> delete(int id, [Transaction? transaction]) {
    final executor = transaction ?? db;
    final rowsDeleted = executor.delete(
      tablename,
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

  /// Returns the total number of rows in the table, optionally filtered.
  Future<int> count({String? where, List<Object?>? whereArgs}) async {
    final sql = StringBuffer('SELECT COUNT(*) AS count FROM $tablename');
    if (where != null && where.isNotEmpty) {
      sql.write(' WHERE $where');
    }
    final result = await db.rawQuery(sql.toString(), whereArgs);
    // Sqflite.firstIntValue handles extracting the count from the result
    return result.first['count'] as int? ?? 0;
  }

  /// Allows you to execute a command against the db
  /// optionally within a transaction.
  DatabaseExecutor withinTransaction(Transaction? transaction) =>
      transaction ?? db;

  DatabaseExecutor withoutTransaction() => db;

  Future<R> withTransaction<R>(
    Future<R> Function(Transaction transaction) callback,
  ) => db.transaction((transaction) => callback(transaction));
}
