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


import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/management/database_helper.dart';
import 'package:hmb/database/versions/project_script_source.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'backup_providers/test_backup_provider.dart';

Database? testDb;
late String testDbPath;

Future<Database> setupTestDb() async {
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
  testDbPath = join(createTempDir(), 'handyman_test_temp.db');

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
  testDb = await openDatabase(testDbPath);

  return testDb!;
}

Future<void> tearDownTestDb() async {
  // Close the database connection
  if (testDb != null) {
    await testDb!.close();
  }

  // Delete the test database
  final testDbPath = join(await getDatabasesPath(), 'handyman_test_temp.db');
  if (exists(testDbPath)) {
    delete(testDbPath);
  }

  testDb = null;
}
