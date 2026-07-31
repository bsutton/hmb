/*
 Copyright © OnePub IP Pty Ltd.
 S. Brett Sutton. All Rights Reserved.
*/

import 'package:sqflite_common/sqlite_api.dart';

/// Allows v208 to rebuild task_item while receipt link tables reference it.
Future<void> pre208Upgrade(Database db) async {
  await db.execute('PRAGMA foreign_keys = OFF');
}

/// Restores enforcement and verifies that the table rebuild preserved links.
Future<void> post208Upgrade(Database db) async {
  try {
    final violations = await db.rawQuery('PRAGMA foreign_key_check');
    final taskItemViolations = violations
        .where((violation) => violation['parent'] == 'task_item')
        .toList();
    if (taskItemViolations.isNotEmpty) {
      throw StateError(
        'Task Item foreign key violations after material price migration: '
        '$taskItemViolations',
      );
    }
  } finally {
    await db.execute('PRAGMA foreign_keys = ON');
  }
}
