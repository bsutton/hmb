/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:sqflite_common/sqlite_api.dart';

import '../factory/hmb_database_factory.dart';
import '../versions/db_upgrade.dart';
import '../versions/script_source.dart';
import 'backup_providers/backup_provider.dart';

class DatabaseHelper {
  factory DatabaseHelper() => instance;
  DatabaseHelper._();
  static Database? _database;
  static final instance = DatabaseHelper._();

  Database get database => _database!;

  Future<void> initDatabase({
    required ScriptSource src,
    required BackupProvider backupProvider,
    required bool backup,
    required HMBDatabaseFactory databaseFactory,
  }) async {
    await openDb(
      src: src,
      backupProvider: backupProvider,
      databaseFactory: databaseFactory,
      backup: backup,
    );
  }

  Future<void> openDb({
    required ScriptSource src,
    required BackupProvider backupProvider,
    required HMBDatabaseFactory databaseFactory,
    required bool backup,
  }) async {
    final path = await backupProvider.databasePath;
    final targetVersion = await getLatestVersion(src);
    print('target db version: $targetVersion');
    _database = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: targetVersion,
        onUpgrade: (db, oldVersion, newVersion) => upgradeDb(
          db: db,
          backup: backup,
          oldVersion: oldVersion,
          newVersion: newVersion,
          src: src,
          backupProvider: backupProvider,
        ),
      ),
    );
  }

  Future<void> closeDb() async {
    final db = database;
    _database = null;
    await db.close();
  }

  bool isOpen() => _database != null;

  Future<int> getVersion() => database.getVersion();

  Future<void> withOpenDatabase(
    HMBDatabaseFactory databaseFactory,
    String pathToDb,
    Future<void> Function() action,
  ) async {
    var wasOpen = false;
    try {
      if (_database == null) {
        _database = await databaseFactory.openDatabase(
          pathToDb,
          options: OpenDatabaseOptions(),
        );
        wasOpen = true;
      }

      await action();
    } finally {
      if (wasOpen) {
        await closeDb();
      }
    }
  }
}
