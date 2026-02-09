import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show getDatabasesPath;

import '../../../util/dart/build_mode.dart';

Future<String> pathToDatabase(String dbFilename) async {
  if (isDebugMode &&
      (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    // When running `flutter run` from the project, pwd == project root
    final dbDir = join(pwd, 'database');
    if (!exists(dbDir)) {
      createDir(dbDir, recursive: true);
    }
    return join(dbDir, dbFilename);
  }
  return join(await getDatabasesPath(), dbFilename);
}
