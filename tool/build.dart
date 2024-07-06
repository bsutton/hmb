#! /home/bsutton/.dswitch/active/dart

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dcli/dcli.dart';
import 'package:hmb/database/management/db_utility.dart';
import 'package:path/path.dart' as path;
import 'package:path/path.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addFlag('assets',
        abbr: 'a',
        help:
            '''Update the list of assets - important to run for db upgrade scripts''')
    ..addFlag('build', abbr: 'b', help: 'build the apk')
    ..addFlag('install', abbr: 'i', help: 'install the apk')
    ..addFlag('release', abbr: 'r', help: 'Create a signed release appbundle suitable to upload to Google Play store.');

  final results = parser.parse(args);

  var build = results['build'] as bool;
  var install = results['install'] as bool;
  var assets = results['assets'] as bool;
  var release = results['release'] as bool;

  if (!build && !install && !assets && !release) {
    /// no switches passed so do it all.
    build = install = assets = true;
  }
  if (release) {
     install= false;
     build = assets = true;
  }

  if (assets) {
    updateAssetList();
  }
  var needPubGet = true;

  if (build) {
    if (needPubGet) {
      _runPubGet();
      needPubGet = false;
    }
    if (release)
    buildAppBundle();
    else
    buildApk();
  }

  if (install) {
    if (needPubGet) {
      _runPubGet();
      needPubGet = false;
    }
    installApk();
  }
}

void _runPubGet() {
  DartSdk().runPubGet(DartProject.self.pathToProjectRoot);
}

void installApk() {
  'flutter install'.run;
}

void buildApk() {
// TODO(bsutton): the rich text editor includes randome icons
// so tree shaking of icons isn't possible. Can we fix this?
  'flutter build apk --no-tree-shake-icons'.run;
}
void buildAppBundle() {
// TODO(bsutton): the rich text editor includes randome icons
// so tree shaking of icons isn't possible. Can we fix this?
  'flutter build appbundle --release --no-tree-shake-icons'.run;
}


void updateAssetList() {
  final pathToAssets = join(
      DartProject.self.pathToProjectRoot, 'assets', 'sql', 'upgrade_scripts');
  final assetFiles = find('v*.sql', workingDirectory: pathToAssets).toList();

  final posix = path.posix;
  final relativePaths = assetFiles

      /// We are creating asset path which must us the posix path delimiter \
      .map((path) {
    final rel = relative(path, from: DartProject.self.pathToProjectRoot);

    /// rebuild the path with posix path delimiter
    return posix.joinAll(split(rel));
  }).toList()

    /// sort in descending order.
    ..sort((a, b) =>
        extractVerionForSQLUpgradeScript(b) -
        extractVerionForSQLUpgradeScript(a));

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
}
