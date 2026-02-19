/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';
import 'dart:developer';
import 'dart:isolate';

import 'package:sqflite_common/sqlite_api.dart' hide DatabaseException;

import '../../util/dart/exceptions.dart';
import '../../util/dart/types.dart';
import '../factory/hmb_database_factory.dart';
import '../versions/db_upgrade.dart';
import '../versions/script_source.dart';
import 'backup_providers/backup_provider.dart';

class DatabaseHelper {
  static Database? _database;
  static final instance = DatabaseHelper._();

  factory DatabaseHelper() => instance;
  DatabaseHelper._();

  Database get database {
    if (_database == null) {
      final isolate = '''
${Service.getIsolateId(Isolate.current)} ${Isolate.current.debugName}''';
      throw DatabaseException(
        """
The database isn't open, if this code is running in an isolate $isolate you will need to explicitly open the db""",
      );
    }
    return _database!;
  }

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

  /// Waits until the shared database is open, or returns false on timeout.
  Future<bool> waitUntilOpen({
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 100),
  }) async {
    if (isOpen()) {
      return true;
    }

    final stopwatch = Stopwatch()..start();
    while (!isOpen()) {
      if (stopwatch.elapsed >= timeout) {
        return false;
      }
      await Future<void>.delayed(pollInterval);
    }

    return true;
  }

  Future<int> getVersion() => database.getVersion();

  Future<void> withOpenDatabase(
    HMBDatabaseFactory databaseFactory,
    String pathToDb,
    AsyncVoidCallback action,
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
