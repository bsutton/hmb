/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:sqflite_common/sqlite_api.dart';

Future<void> prev154Upgrade(Database db) async {
  final tables = await db.rawQuery('''
SELECT name
FROM sqlite_master
WHERE type = 'table'
AND name = 'backup_history'
''');
  if (tables.isEmpty) {
    return;
  }

  final tableInfo = await db.rawQuery('PRAGMA table_info(backup_history)');
  final columns = {
    for (final row in tableInfo) row['name'] as String? ?? '': true,
  };

  if (columns.containsKey('operation') &&
      columns.containsKey('occurred_at') &&
      columns.containsKey('modified_date')) {
    return;
  }

  await db.execute('DROP INDEX IF EXISTS backup_history_op_success_when_idx');
  await db.execute('''
CREATE TABLE backup_history_v154 (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  provider TEXT NOT NULL,
  operation TEXT NOT NULL,
  success INTEGER NOT NULL,
  error TEXT,
  occurred_at TEXT NOT NULL,
  created_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  modified_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)
''');

  final operationExpression = columns.containsKey('operation')
      ? "COALESCE(operation, 'backup')"
      : columns.containsKey('backup_type')
      ? '''
CASE backup_type
  WHEN 'restore' THEN 'restore'
  WHEN 'photo_sync' THEN 'photo_sync'
  ELSE 'backup'
END
'''
      : "'backup'";
  final occurredAtExpression = columns.containsKey('occurred_at')
      ? 'COALESCE(occurred_at, created_date, CURRENT_TIMESTAMP)'
      : columns.containsKey('created_date')
      ? 'COALESCE(created_date, CURRENT_TIMESTAMP)'
      : 'CURRENT_TIMESTAMP';
  final createdDateExpression = columns.containsKey('created_date')
      ? 'COALESCE(created_date, CURRENT_TIMESTAMP)'
      : occurredAtExpression;
  final modifiedDateExpression = columns.containsKey('modified_date')
      ? 'COALESCE(modified_date, created_date, CURRENT_TIMESTAMP)'
      : createdDateExpression;

  await db.execute('''
INSERT INTO backup_history_v154 (
  id,
  provider,
  operation,
  success,
  error,
  occurred_at,
  created_date,
  modified_date
)
SELECT
  id,
  provider,
  $operationExpression,
  COALESCE(success, 0),
  error,
  $occurredAtExpression,
  $createdDateExpression,
  $modifiedDateExpression
FROM backup_history
''');

  await db.execute('DROP TABLE backup_history');
  await db.execute('ALTER TABLE backup_history_v154 RENAME TO backup_history');
}
