import 'package:dcli/dcli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/management/backup_providers/local/local_backup_provider.dart';
import 'package:hmb/database/management/database_helper.dart';
import 'package:hmb/database/versions/project_script_source.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Database? testDb;

Future<Database> setupTestDb() async {
  final project = DartProject.self;
  // Path to the clean database in the fixtures directory
  final cleanDbPath = join(
      project.pathToProjectRoot, 'test', 'fixture', 'db', 'handyman_test.db');

  // Path where the test database will be copied to and used
  final testDbPath = join(createTempDir(), 'handyman_test_temp.db');

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
      pathToDb: testDbPath,
      src: ProjectScriptSource(),
      backupProvider: LocalBackupProvider(CliDatabaseFactory()),
      databaseFactory: CliDatabaseFactory(),
      backup: false);
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
