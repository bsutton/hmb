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

import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/management/database_helper.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:path/path.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common/sqflite.dart';

import 'backup_providers/test_backup_provider.dart';

Database? testDb;
late String testDbPath;

String _linuxSafeTempDir() {
  final tempDir = createTempDir();

  // In some Linux/WSL setups TEMP/TMP can contain a Windows-style path
  // (e.g. C:\Users\...), which is treated as a relative path on Linux.
  // Fall back to a real Linux temp dir to avoid creating files in cwd.
  if (!Platform.isWindows && RegExp(r'^[A-Za-z]:[\\/]').hasMatch(tempDir)) {
    return Directory.systemTemp.createTempSync('hmb_test_temp').path;
  }

  return tempDir;
}

class _TestPathProvider
    with Fake, MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String tempPath = Directory.systemTemp
      .createTempSync('hmb_test_temp')
      .path;
  final String docPath = Directory.systemTemp
      .createTempSync('hmb_test_docs')
      .path;

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docPath;
}

Future<Database> setupTestDb() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _TestPathProvider();

  final project = DartProject.self;
  // Path to the clean database in the fixtures directory
  final cleanDbPath = join(
    project.pathToProjectRoot,
    'test',
    'fixture',
    'db',
    'handyman_test.db',
  );

  // Path where the test database will be copied to and used
  testDbPath = join(_linuxSafeTempDir(), 'handyman_test_temp.db');

  print('Running against test db at: $testDbPath');

  // Ensure the test db directory exists
  final dbDir = dirname(testDbPath);
  if (!exists(dbDir)) {
    createDir(dbDir, recursive: true);
  }

  // Copy the clean db to the test directory
  copy(cleanDbPath, testDbPath);

  // Open the copied database for testing
  await DatabaseHelper().initDatabase(
    src: ProjectScriptSource(),
    backupProvider: TestBackupProvider(CliDatabaseFactory(), testDbPath),
    databaseFactory: CliDatabaseFactory(),
    backup: false,
  );
  testDb = DatabaseHelper().database;

  return testDb!;
}

Future<void> tearDownTestDb() async {
  // Close the database connection
  if (testDb != null) {
    await testDb!.close();
  }
  if (DatabaseHelper().isOpen()) {
    await DatabaseHelper().closeDb();
  }

  // Delete the test database
  if (exists(testDbPath)) {
    delete(testDbPath);
  }

  testDb = null;
}
