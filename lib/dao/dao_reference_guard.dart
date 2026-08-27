import 'package:sqflite_common/sqlite_api.dart';

import '../util/dart/exceptions.dart';

class DaoReference {
  final String table;
  final String column;
  final String label;

  const DaoReference(this.table, this.column, this.label);
}

class DaoReferenceGuard {
  const DaoReferenceGuard._();

  static Future<void> ensureNotReferenced({
    required DatabaseExecutor db,
    required String entityName,
    required int id,
    required Iterable<DaoReference> references,
  }) async {
    final dependencies = <String>[];
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tables = tableRows
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();
    for (final reference in references) {
      if (!tables.contains(reference.table)) {
        continue;
      }
      final columnRows = await db.rawQuery(
        'PRAGMA table_info(${reference.table})',
      );
      final columns = columnRows
          .map((row) => row['name'])
          .whereType<String>()
          .toSet();
      if (!columns.contains(reference.column)) {
        continue;
      }
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM ${reference.table} '
        'WHERE ${reference.column} = ?',
        [id],
      );
      final count = rows.first['count'] as int? ?? 0;
      if (count > 0) {
        dependencies.add('${reference.label}: $count');
      }
    }
    if (dependencies.isNotEmpty) {
      throw HMBException(
        '$entityName cannot be deleted while it is referenced by '
        '${dependencies.join(', ')}.',
      );
    }
  }
}
