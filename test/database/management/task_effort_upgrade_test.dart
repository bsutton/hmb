import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/entity/task.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test(
    'v218 keeps legacy task details and adds optional comparison fields',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'hmb-effort-upgrade-',
      );
      final db = await CliDatabaseFactory().openDatabase(
        '${directory.path}/test.db',
        options: OpenDatabaseOptions(),
      );
      try {
        for (final path in [
          'test/sql/task_effort_v213.sql',
          'assets/sql/upgrade_scripts/v218.sql',
        ]) {
          for (final sql in await parseSqlFile(
            await File(path).readAsString(),
          )) {
            await db.execute(sql);
          }
        }
        final task = Task.fromMap((await db.query('task')).single);
        expect(task.name, 'Existing work');
        expect(task.categoryId, isNull);
        expect(task.effortQuantity, isNull);
        expect(task.effortUnit, isEmpty);
        expect(task.effortNotes, isEmpty);
      } finally {
        await db.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
