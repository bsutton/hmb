#! /home/bsutton/.dswitch/active/dart

import 'dart:io';

import 'package:args/args.dart';
import 'package:dcli/dcli.dart';
import 'package:path/path.dart';

/// Launch the sqlite3 command line tool connected to the local
/// dev database

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h')
    ..addFlag('test', abbr: 't', help: 'Connect to the test fixtures db');

  final results = parser.parse(args);
  if (results['help'] as bool || results.arguments.isEmpty) {
    print(parser.usage);
    exit(0);
  }
  var pathToDb = join(DartProject.self.pathToDartToolDir, 'sqflite_common_ffi',
      'databases', 'handyman.db');

  if (results['test'] as bool) {
    pathToDb =
        join(DartProject.self.pathToTestDir, 'fixture', 'db', 'handyman_test.db');
  }

  'sqlite3 $pathToDb'.start(terminal: true);
}
