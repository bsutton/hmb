import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/entity/tool.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test(
    'v215 preserves existing tools and initializes empty location',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'hmb-tool-upgrade-',
      );
      final db = await CliDatabaseFactory().openDatabase(
        '${directory.path}/test.db',
        options: OpenDatabaseOptions(),
      );
      try {
        for (final path in [
          'test/sql/tool_location_v213.sql',
          'assets/sql/upgrade_scripts/v215.sql',
        ]) {
          for (final sql in await parseSqlFile(
            await File(path).readAsString(),
          )) {
            await db.execute(sql);
          }
        }
        final tool = Tool.fromMap((await db.query('tool')).single);
        expect(tool.name, 'Existing drill');
        expect(tool.location, isEmpty);
        expect(tool.lentTo, isEmpty);
      } finally {
        await db.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
