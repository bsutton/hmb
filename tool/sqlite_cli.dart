#! /home/bsutton/.dswitch/active/dart

import 'package:dcli/dcli.dart';
import 'package:path/path.dart';

/// Launch the sqlite3 command line tool connected to the local
/// dev database

void main(List<String> args) async {
  final pathToDb = join(DartProject.self.pathToDartToolDir,
      'sqflite_common_ffi', 'databases', 'handyman.db');
  'sqlite3 $pathToDb'.start(terminal: true);
}
