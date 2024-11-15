import 'package:sqflite/sqlite_api.dart';
import 'package:strings/strings.dart';

import '../../entity/version.dart';
import '../../src/version/version.g.dart' as code;
import '../management/backup_providers/backup_provider.dart';
import '../management/db_utility.dart';
import 'post_upgrade_77.dart';
import 'script_source.dart';

/// Upgrade the database by applying each upgrade script in order
/// from the db's current version to the latest version.
Future<void> upgradeDb(
    {required Database db,
    required int oldVersion,
    required int newVersion,
    required bool backup,
    required ScriptSource src,
    required BackupProvider backupProvider}) async {
  if (oldVersion == 1) {
    print('Creating database');
  } else {
    if (backup) {
      print('Backing up database prior to upgrade');

      await backupProvider.performBackup(version: oldVersion, src: src);
      print('Upgrade database from Version $oldVersion');
    } else {
      print('Skipping backup');
    }
  }
  final upgradeAssets = await src.upgradeScripts();

  // sort the list of upgrade script numerically after stripping
  // of the .sql extension.
  upgradeAssets.sort((a, b) =>
      extractVerionForSQLUpgradeScript(a) -
      extractVerionForSQLUpgradeScript(b));

  final firstUpgrade = oldVersion + 1;

  /// find the first scrip to be applied
  var index = 0;
  for (; index < upgradeAssets.length; index++) {
    final pathToScript = upgradeAssets[index];
    final scriptVersion = extractVerionForSQLUpgradeScript(pathToScript);
    if (scriptVersion >= firstUpgrade) {
      print('Upgrading to $scriptVersion via $pathToScript');
      await _executeScript(db, src, pathToScript);

      /// invoke any registered post upgrade actions for [scriptVersion]
      if (upgradeActions.containsKey(scriptVersion)) {
        await upgradeActions[scriptVersion]!.call(db);
      }

      await insertVersion(
          db,
          Version.forInsert(
              dbVersion: scriptVersion, codeVersion: code.packageVersion));
    }
  }
}

final upgradeActions = <int, Future<void> Function(Database)>{
  77: postv77Upgrade
};

/// We can't use the Dao layer as it uses June which assumes
/// data:ui is available which from the CLI it isn't.
Future<void> insertVersion(Database db, Version version) async {
  // We didn't have a version table before v71.
  if (version.dbVersion > 71) {
    version
      ..createdDate = DateTime.now()
      ..modifiedDate = DateTime.now();
    final id = await db.insert('version', version.toMap()..remove('id'));
    version.id = id;
  }
}

Future<int> getLatestVersion(ScriptSource src) async {
  final upgradeAssets = await src.upgradeScripts();

  // sort the list of upgrade script numerically after stripping
  // of the .sql extension.
  upgradeAssets.sort((a, b) =>
      extractVerionForSQLUpgradeScript(a) -
      extractVerionForSQLUpgradeScript(b));

  return extractVerionForSQLUpgradeScript(upgradeAssets.last);
}

Future<void> _executeScript(
    Database db, ScriptSource src, String pathToScript) async {
  final sql = await src.loadSQL(pathToScript);

  print('running $src.pathToScript');
  final statements = await parseSqlFile(sql);

  for (final statement in statements) {
    if (Strings.isEmpty(statement)) {
      continue;
    }
    print('running: $statement');
    await db.transaction((txn) async => txn.execute(statement));
  }
}

Future<void> x(Database db, String command) async {
  await db.execute(command);
}

Future<List<String>> parseSqlFile(String content) async {
  final statements = <String>[];
  final buffer = StringBuffer();
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inComment = false;

  for (var i = 0; i < content.length; i++) {
    final char = content[i];
    final nextChar = i + 1 < content.length ? content[i + 1] : '';

    // Detect start of comment
    if (!inSingleQuote &&
        !inDoubleQuote &&
        !inComment &&
        char == '-' &&
        nextChar == '-') {
      inComment = true;
      i++; // Skip the next '-' character
      continue;
    }

    // Ignore characters within a comment until the end of the line
    if (inComment) {
      if (char == '\n') {
        inComment = false;
        buffer.write(char); // Include the newline character
      }
      continue;
    }

    // Toggle single quote context
    if (char == "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
      buffer.write(char);
      continue;
    }

    // Toggle double quote context
    if (char == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      buffer.write(char);
      continue;
    }

    // Handle semicolon outside of quotes
    if (char == ';' && !inSingleQuote && !inDoubleQuote) {
      statements.add(buffer.toString().trim());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }

  if (buffer.isNotEmpty) {
    statements.add(buffer.toString().trim());
  }

  return statements;
}
