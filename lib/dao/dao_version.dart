import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/version.dart';
import 'dao.dart';

class DaoVersion extends Dao<Version> {
  Future<void> createTable(Database db, int version) async {
    await db.execute('''
      CREATE TABLE version (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        db_version INTEGER NOT NULL,
        code_version TEXT NOT NULL,
        created_date TEXT DEFAULT CURRENT_TIMESTAMP,
        modified_date TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  @override
  Version fromMap(Map<String, dynamic> map) => Version.fromMap(map);

  Future<Version?> getLatestVersion() async {
    final db = getDb();
    final result = await db.query(
      tableName,
      orderBy: 'db_version DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return fromMap(result.first);
    }
    return null;
  }

  @override
  String get tableName => 'version';
  @override
  JuneStateCreator get juneRefresher => VersionState.new;
}

/// Used to notify the UI when the version entry changes.
class VersionState extends JuneState {
  VersionState();
}
