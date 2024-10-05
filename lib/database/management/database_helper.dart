import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../versions/db_upgrade.dart';

class DatabaseHelper {
  factory DatabaseHelper() => instance;
  DatabaseHelper._();
  static Database? _database;
  static final DatabaseHelper instance = DatabaseHelper._();

  Database get database => _database!;

  Future<void> initDatabase() async {
    _initDatabaseFactory();

    await openDb();
  }

  Future<void> openDb() async {
    final path = await pathToDatabase();
    _database = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: await getLatestVersion(),
            onUpgrade: (db, oldVersion, newVersion) => upgradeDb(
                db: db,
                backup: kIsWeb,
                oldVersion: oldVersion,
                newVersion: newVersion)
            ));
  }

  Future<String> pathToDatabase() async {
    final path = join(await getDatabasesPath(), 'handyman.db');
    return path;
  }

  Future<void> closeDb() async {
    final db = database;
    _database = null;
    await db.close();
  }

  void _initDatabaseFactory() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        /// required for non-mobile platforms.
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } else if (Platform.isAndroid || Platform.isIOS) {
        /// uses the default factory.
      }
    }
  }

  bool isOpen() => _database != null;

  Future<int> getVersion() async => database.getVersion();
}
