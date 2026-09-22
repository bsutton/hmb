import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test('v217 preserves historical billable time', () async {
    final directory = Directory.systemTemp.createTempSync('hmb-time-upgrade-');
    final db = await CliDatabaseFactory().openDatabase(
      '${directory.path}/test.db',
      options: OpenDatabaseOptions(),
    );
    try {
      for (final path in [
        'test/sql/nonbillable_time_v214.sql',
        'assets/sql/upgrade_scripts/v217.sql',
      ]) {
        for (final sql in await parseSqlFile(await File(path).readAsString())) {
          await db.execute(sql);
        }
      }
      final row = (await db.query('time_entry')).single;
      expect(row['notes'], 'Existing tracked work');
      expect(row['billed'], 1);
      expect(row['billable'], 1);
      expect(row['show_on_invoice'], 0);
    } finally {
      await db.close();
      directory.deleteSync(recursive: true);
    }
  });
}
