#! /usr/bin/env dcli

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

import 'dart:convert';
import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/management/backup_providers/dev/dev_backup_provider.dart';
import 'package:hmb/database/management/db_utility.dart';
import 'package:hmb/database/versions/db_upgrade.dart';
import 'package:hmb/database/versions/implementations/project_script_source.dart';
import 'package:path/path.dart' as path;
import 'package:path/path.dart';
import 'package:pub_release/pub_release.dart' hide Settings;
import 'package:pubspec_manager/pubspec_manager.dart' as pm;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'lib/android_validation.dart';
import 'lib/build_artifact_cache.dart';
import 'lib/build_options.dart';
import 'lib/version_properties.dart';

Future<void> main(List<String> args) async {
  try {
    await _runBuild(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    showUsage();
    exitCode = 64;
    // The validation API reports expected preflight failures as StateError.
    // ignore: avoid_catching_errors
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

Future<void> _runBuild(List<String> args) async {
  final options = BuildOptions(args);
  Settings().setVerbose(enabled: false);
  if (options.help) {
    showUsage();
    return;
  }
  options.validate();
  final build = options.build;
  final install = options.install;
  final assets = options.assets;
  final release = options.release;
  final previousOverride =
      options.previousArtifact ?? Platform.environment['HMB_PREVIOUS_ARTIFACT'];
  final cache = BuildArtifactCache();
  AndroidValidation? validation;
  ValidatedArtifact? validatedApk;
  if (install &&
      !build &&
      (previousOverride == null || previousOverride.trim().isEmpty)) {
    validatedApk = await cache.validatedCandidate(_apkPath);
    if (validatedApk != null) {
      print('Reusing successful Android validation for the unchanged APK.');
    }
  }
  if (build || (install && validatedApk == null)) {
    if (build) {
      await cache.preserveExistingOutput(_apkPath);
      await cache.preserveExistingOutput(_aabPath);
    }
    final previous = await cache.resolvePrevious(
      candidatePath: release ? _aabPath : _apkPath,
      building: build,
      explicitPath: previousOverride,
    );
    print('Using preserved upgrade baseline: $previous');
    validation = AndroidValidation(previousArtifact: previous)
      ..preflight(release ? 'candidate.aab' : 'candidate.apk');
  }

  if (assets) {
    await updateAssetList();
  }

  if (build) {
    if (!which('flutter').found) {
      throw StateError('Missing flutter');
    }
    final pathToPubSpec = DartProject.self.pathToPubSpec;
    final currentVersion = version(pubspecPath: pathToPubSpec)!;
    final newVersion = askForVersion(currentVersion);
    updateVersion(newVersion, pm.PubSpec.load(), pathToPubSpec);

    updateAndroidVersion(newVersion);

    if (options.clean) {
      _checkedFlutter(['clean']);
    }
    _runPubGet();

    /// remove the pdfx wasm modules as the add 4mb and
    /// they are only useful on web.
    /// https://github.com/espresso3389/pdfrx/tree/master/packages/pdfrx#note-for-building-release-builds
    // 'flutter run pdfrx:remove_wasm_modules'.run;
    if (release) {
      await buildAppBundle(newVersion, validation!, cache);
    } else {
      buildApk();
      validatedApk = await validation!.validate(_apkPath);
      await cache.recordValidated(
        candidate: validatedApk,
        previousPath: validation.previousArtifact,
      );
    }
  }

  if (install) {
    if (validatedApk == null) {
      validatedApk = await validation!.validate(_apkPath);
      await cache.recordValidated(
        candidate: validatedApk,
        previousPath: validation.previousArtifact,
      );
    }
    await validatedApk.assertUnchanged();
    installApk(device: options.device);
  }
}

void showUsage() {
  print('''
Tools to help build the app
  Assets, build and install are enabled by default.
  Disable steps with --no-assets, --no-build or --no-install.
  Upgrade baselines are preserved automatically before cleaning.
  ''');
  print(BuildOptions.parser.usage);
}

void _runPubGet() {
  _checkedFlutter(['pub', 'get', '--enforce-lockfile']);
}

void installApk({String? device}) {
  print(
    orange('Make certain you have first run --build so you get the latest apk'),
  );

  final serial = _selectAndroidInstallTarget(device);
  print(orange('Installing APK to Android device $serial'));
  final args = [
    '-s',
    serial,
    'install',
    '-r',
    'build/app/outputs/flutter-apk/app-release.apk',
  ];
  final result = Process.runSync('adb', args);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(
      'adb',
      args,
      result.stderr.toString(),
      result.exitCode,
    );
  }
}

String _selectAndroidInstallTarget(String? requestedSerial) {
  final result = Process.runSync('adb', ['devices', '-l']);
  if (result.exitCode != 0) {
    throw ProcessException(
      'adb',
      ['devices', '-l'],
      result.stderr.toString(),
      result.exitCode,
    );
  }

  final devices = result.stdout
      .toString()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => RegExp(r'^\S+\s+device(?:\s|$)').hasMatch(line))
      .toList();

  if (devices.isEmpty) {
    throw StateError(
      'No Android devices are attached. '
      'Start an emulator or connect a device, then run adb devices -l.',
    );
  }

  if (requestedSerial != null && requestedSerial.isNotEmpty) {
    final isConnected = devices.any(
      (line) => line.startsWith('$requestedSerial '),
    );
    if (!isConnected) {
      throw StateError(
        'Device $requestedSerial is not connected. '
        'Connected devices:\n${devices.join('\n')}',
      );
    }
    return requestedSerial;
  }

  final usbDevices = devices.where((line) => line.contains(' usb:')).toList();
  if (usbDevices.length == 1) {
    return usbDevices.single.split(RegExp(r'\s+')).first;
  }
  if (usbDevices.isEmpty && devices.length == 1) {
    return devices.single.split(RegExp(r'\s+')).first;
  }

  throw StateError(
    'Expected exactly one USB-connected Android device. '
    'Use --device <serial> to choose a target.',
  );
}

const _apkPath = 'build/app/outputs/flutter-apk/app-release.apk';
const _aabPath = 'build/app/outputs/bundle/release/app-release.aab';

void _checkedFlutter(List<String> arguments) {
  final result = Process.runSync('flutter', arguments);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(
      'flutter',
      arguments,
      'Flutter command failed',
      result.exitCode,
    );
  }
}

void buildApk() {
  _checkedFlutter([
    'build',
    'apk',
    '--release',
    '--no-pub',
    '--no-tree-shake-icons',
  ]);
}

Future<void> buildAppBundle(
  Version newVersion,
  AndroidValidation validation,
  BuildArtifactCache cache,
) async {
  _checkedFlutter([
    'build',
    'appbundle',
    '--release',
    '--no-pub',
    '--no-tree-shake-icons',
  ]);
  final validated = await validation.validate(_aabPath);
  await cache.recordValidated(
    candidate: validated,
    previousPath: validation.previousArtifact,
  );

  final targetPath = join(
    DartProject.self.pathToProjectRoot,
    'release',
    'hmb-$newVersion.aab',
  );
  await validated.assertUnchanged();
  if (exists(targetPath)) {
    delete(targetPath);
  }
  // move the generated aab into our release directory.
  move(
    join('build', 'app', 'outputs', 'bundle', 'release', 'app-release.aab'),
    targetPath,
  );
  print(orange('Moved the bundle to $targetPath'));
}

/// Update the list of sql upgrade scripts we ship as assets.
/// The lists is held in assets/sql/upgrade_list.json
Future<void> updateAssetList() async {
  final pathToAssets = join(
    DartProject.self.pathToProjectRoot,
    'assets',
    'sql',
    'upgrade_scripts',
  );
  final assetFiles = find('v*.sql', workingDirectory: pathToAssets).toList();

  final posix = path.posix;
  final relativePaths =
      assetFiles
        /// We are creating asset path which must us the posix path delimiter \
        .map((path) {
          final rel = relative(path, from: DartProject.self.pathToProjectRoot);
          return posix.joinAll(split(rel));
        }).toList()
        ..sort(
          (a, b) =>
              extractVerionForSQLUpgradeScript(b) -
              extractVerionForSQLUpgradeScript(a),
        );

  var jsonContent = jsonEncode(relativePaths);

  // make the json file more readable
  jsonContent = jsonContent.replaceAllMapped(
    RegExp(r'\[|\]'),
    (match) => match.group(0) == '[' ? '[\n  ' : '\n]',
  );
  jsonContent = jsonContent.replaceAll(RegExp(r',\s*'), ',\n  ');

  final jsonFile = File('assets/sql/upgrade_list.json')
    ..writeAsStringSync(jsonContent);

  print('SQL Asset list generated: ${jsonFile.path}');

  // After updating the assets, create the clean test database.
  await createCleanTestDatabase();
}

/// Method to create a new clean database for unit testing.
Future<void> createCleanTestDatabase() async {
  final testDbPath = join(
    Directory.current.path,
    'test',
    'fixture',
    'db',
    'handyman_test.db',
  );

  // Ensure the directory exists
  final dbDir = dirname(testDbPath);
  if (!exists(dbDir)) {
    createDir(dbDir, recursive: true);
  }

  final databaseFactory = CliDatabaseFactory();
  final src = ProjectScriptSource();
  final db = await databaseFactory.openDatabase(
    testDbPath,
    options: OpenDatabaseOptions(
      version: await getLatestVersion(src),
      onUpgrade: (db, oldVersion, newVersion) => upgradeDb(
        db: db,
        oldVersion: oldVersion,
        newVersion: newVersion,
        backup: true,
        src: src,
        backupProvider: DevBackupProvider(databaseFactory),
      ),
    ),
  );

  print('Clean test database created at: $testDbPath');
  await db.close();
}
