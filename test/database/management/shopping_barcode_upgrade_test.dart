import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test(
    'v216 preserves existing items and initializes optional barcode',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'hmb-barcode-upgrade-',
      );
      final db = await CliDatabaseFactory().openDatabase(
        '${directory.path}/test.db',
        options: OpenDatabaseOptions(),
      );
      try {
        for (final path in [
          'test/sql/shopping_barcode_v213.sql',
          'assets/sql/upgrade_scripts/v216.sql',
        ]) {
          for (final sql in await parseSqlFile(
            await File(path).readAsString(),
          )) {
            await db.execute(sql);
          }
        }
        final row = (await db.query('task_item')).single;
        expect(row['description'], 'Existing shopping item');
        expect(row['barcode'], '');
      } finally {
        await db.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
