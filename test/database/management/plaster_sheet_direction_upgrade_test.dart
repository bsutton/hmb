import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:path/path.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test('v166 adds persisted sheet direction columns', () async {
    final dbPath = join(createTempDir(), 'plaster_sheet_direction_v166.db');
    final db = await CliDatabaseFactory().openDatabase(
      dbPath,
      options: OpenDatabaseOptions(),
    );

    try {
      final source = ProjectScriptSource();
      for (final script in [
        'assets/sql/upgrade_scripts/v163.sql',
        'assets/sql/upgrade_scripts/v166.sql',
      ]) {
        final sql = await source.loadSQL(script);
        final statements = await parseSqlFile(sql);
        for (final statement in statements) {
          await db.execute(statement);
        }
      }

      final roomColumns = await db.rawQuery('PRAGMA table_info(plaster_room)');
      final lineColumns = await db.rawQuery(
        'PRAGMA table_info(plaster_room_line)',
      );
      final roomNames = {
        for (final row in roomColumns) row['name'] as String? ?? '': true,
      };
      final lineNames = {
        for (final row in lineColumns) row['name'] as String? ?? '': true,
      };

      expect(roomNames.containsKey('ceiling_sheet_direction'), isTrue);
      expect(lineNames.containsKey('sheet_direction'), isTrue);
    } finally {
      await db.close();
      delete(dbPath);
    }
  });
}
