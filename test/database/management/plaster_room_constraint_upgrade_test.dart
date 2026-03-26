import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:path/path.dart';
import 'package:sqflite_common/sqlite_api.dart';

void main() {
  test('v165 is idempotent for plaster room constraints', () async {
    final dbPath = join(createTempDir(), 'plaster_room_constraint_v165.db');
    final db = await CliDatabaseFactory().openDatabase(
      dbPath,
      options: OpenDatabaseOptions(),
    );

    try {
      final source = ProjectScriptSource();
      for (final script in [
        'assets/sql/upgrade_scripts/v163.sql',
        'assets/sql/upgrade_scripts/v165.sql',
      ]) {
        final sql = await source.loadSQL(script);
        final statements = await parseSqlFile(sql);
        for (final statement in statements) {
          await db.execute(statement);
        }
      }

      final sql = await source.loadSQL('assets/sql/upgrade_scripts/v165.sql');
      final statements = await parseSqlFile(sql);
      for (final statement in statements) {
        await db.execute(statement);
      }

      final columns = await db.rawQuery(
        'PRAGMA table_info(plaster_room_constraint)',
      );
      final names = {
        for (final row in columns) row['name'] as String? ?? '': true,
      };

      expect(names.containsKey('room_id'), isTrue);
      expect(names.containsKey('line_id'), isTrue);
      expect(names.containsKey('type'), isTrue);
      expect(names.containsKey('target_value'), isTrue);
    } finally {
      await db.close();
      delete(dbPath);
    }
  });
}
