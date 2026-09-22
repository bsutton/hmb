import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test(
    'v220 leaves room geometry intact and cascades paint settings',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'hmb-paint-upgrade-',
      );
      final db = await CliDatabaseFactory().openDatabase(
        '${directory.path}/test.db',
        options: OpenDatabaseOptions(),
      );
      try {
        await db.execute('PRAGMA foreign_keys = ON');
        for (final path in [
          'test/sql/paint_room_v213.sql',
          'assets/sql/upgrade_scripts/v220.sql',
        ]) {
          for (final sql in await parseSqlFile(
            await File(path).readAsString(),
          )) {
            await db.execute(sql);
          }
        }
        expect(
          (await db.query('plaster_room')).single['name'],
          'Existing room',
        );
        expect(await db.query('paint_room_estimate'), isEmpty);
        await db.insert('paint_room_estimate', {
          'room_id': 1,
          'settings_json': '{}',
        });
        await db.delete('plaster_room', where: 'id = 1');
        expect(await db.query('paint_room_estimate'), isEmpty);
      } finally {
        await db.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
}
