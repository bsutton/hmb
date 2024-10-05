import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:strings/strings.dart';

import '../management/backup_providers/local/local_backup_provider.dart';
import '../management/db_utility.dart';

/// Upgrade the database by applying each upgrade script in order
/// from the db's current version to the latest version.
Future<void> upgradeDb(
    {required Database db,
    required int oldVersion,
    required int newVersion,
    required bool backup}) async {
  if (oldVersion == 1) {
    print('Creating database');
  } else {
    if (backup) {
      print("Skipping backup as we don't have a solution");
    } else {
      print('Backing up database prior to upgrade');

      await LocalBackupProvider().performBackup(version: oldVersion);
      print('Upgrade database from Version $oldVersion');
    }
  }
  final upgradeAssets = await _loadPathsToUpgradeScriptAssets();

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
      await _executeScript(db, pathToScript);
    }
  }
}

Future<int> getLatestVersion() async {
  final upgradeAssets = await _loadPathsToUpgradeScriptAssets();

  // sort the list of upgrade script numerically after stripping
  // of the .sql extension.
  upgradeAssets.sort((a, b) =>
      extractVerionForSQLUpgradeScript(a) -
      extractVerionForSQLUpgradeScript(b));

  return extractVerionForSQLUpgradeScript(upgradeAssets.last);
}

Future<void> _executeScript(Database db, String pathToScript) async {
  final sql = await rootBundle.loadString(pathToScript);
  print('running $pathToScript');
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

Future<List<String>> _loadPathsToUpgradeScriptAssets() async {
  final jsonString =
      await rootBundle.loadString('assets/sql/upgrade_list.json');
  return List<String>.from(json.decode(jsonString) as List);
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
