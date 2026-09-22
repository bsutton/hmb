import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/entity/trip_log.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test('v219 preserves jobs and starts tracking disabled', () async {
    final directory = Directory.systemTemp.createTempSync('hmb-trip-upgrade-');
    final db = await CliDatabaseFactory().openDatabase(
      '${directory.path}/test.db',
      options: OpenDatabaseOptions(),
    );
    try {
      for (final path in [
        'test/sql/trip_log_v213.sql',
        'assets/sql/upgrade_scripts/v219.sql',
      ]) {
        for (final sql in await parseSqlFile(await File(path).readAsString())) {
          await db.execute(sql);
        }
      }
      expect(await db.query('job'), hasLength(1));
      final settings = TripSettings.fromMap(
        (await db.query('trip_settings')).single,
      );
      expect(settings.enabled, isFalse);
      expect(settings.routeLookupEnabled, isFalse);
      expect(await db.query('trip_log'), isEmpty);
    } finally {
      await db.close();
      directory.deleteSync(recursive: true);
    }
  });
}
