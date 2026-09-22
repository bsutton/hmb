import 'package:sqflite_common/sqlite_api.dart';

import 'billing_mutation.dart';

/// Shared by DAO CRUD and custom map-based updates.
/// Reads pass straight through.
/// Transactions supplied by a business operation are reused, never nested.
class BillingExecutor implements DatabaseExecutor {
  final DatabaseExecutor _executor;
  BillingExecutor(this._executor);

  Future<T> _write<T>(
    String table,
    Future<T> Function(DatabaseExecutor executor) action,
  ) {
    if (!BillingMutation.enabled(database) ||
        !BillingMutation.tables.contains(table)) {
      return action(_executor);
    }
    if (_executor is Transaction) {
      return action(_executor);
    }
    return database.transaction(action);
  }

  bool _tracks(String table) =>
      BillingMutation.enabled(database) &&
      BillingMutation.tables.contains(table);

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) => _write(table, (db) async {
    final id = await db.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
    if (_tracks(table) && id != 0) {
      final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
      await BillingMutation.enqueue(
        db,
        await BillingMutation.jobs(db, table, rows),
      );
    }
    return id;
  });

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) => _write(table, (db) async {
    final before = _tracks(table)
        ? (await db.query(table, where: where, whereArgs: whereArgs))
              .where((row) => BillingMutation.changed(table, row, values))
              .toList()
        : <Map<String, Object?>>[];
    final jobs = await BillingMutation.jobs(db, table, before);
    final count = await db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    if (before.isNotEmpty) {
      jobs.addAll(
        await BillingMutation.jobs(
          db,
          table,
          before.map((row) => {...row, ...values}),
        ),
      );
      await BillingMutation.enqueue(db, jobs);
    }
    return count;
  });

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      _write(table, (db) async {
        final rows = _tracks(table)
            ? await db.query(table, where: where, whereArgs: whereArgs)
            : <Map<String, Object?>>[];
        final jobs = await BillingMutation.jobs(db, table, rows);
        final count = await db.delete(
          table,
          where: where,
          whereArgs: whereArgs,
        );
        if (table == 'job') {
          for (final id in jobs) {
            await db.delete(
              'job_billing_state',
              where: 'job_id = ?',
              whereArgs: [id],
            );
          }
        } else {
          await BillingMutation.enqueue(db, jobs);
        }
        return count;
      });

  @override
  Database get database => _executor.database;
  @override
  Batch batch() => _executor.batch();
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      _executor.execute(sql, arguments);
  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      _executor.rawInsert(sql, arguments);
  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      _executor.rawUpdate(sql, arguments);
  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      _executor.rawDelete(sql, arguments);
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => _executor.rawQuery(sql, arguments);
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) => _executor.query(
    table,
    distinct: distinct,
    columns: columns,
    where: where,
    whereArgs: whereArgs,
    groupBy: groupBy,
    having: having,
    orderBy: orderBy,
    limit: limit,
    offset: offset,
  );
  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) => _executor.rawQueryCursor(sql, arguments, bufferSize: bufferSize);
  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) => _executor.queryCursor(
    table,
    distinct: distinct,
    columns: columns,
    where: where,
    whereArgs: whereArgs,
    groupBy: groupBy,
    having: having,
    orderBy: orderBy,
    limit: limit,
    offset: offset,
    bufferSize: bufferSize,
  );
}
