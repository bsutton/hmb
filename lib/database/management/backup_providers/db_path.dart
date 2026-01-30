import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show getDatabasesPath;

Future<String> pathToDatabase(String dbFilename) async =>
    join(await getDatabasesPath(), dbFilename);
