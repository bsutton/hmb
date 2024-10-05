import 'package:sqflite_common/sqlite_api.dart';

abstract class HMBDatabaseFactory {
  Future<Database> openDatabase(String path,
      {required OpenDatabaseOptions options});
}
