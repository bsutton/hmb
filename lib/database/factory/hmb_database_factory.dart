import 'package:sqflite_common/sqlite_api.dart';

// ignore: one_member_abstracts
abstract class HMBDatabaseFactory {
  Future<Database> openDatabase(String path,
      {required OpenDatabaseOptions options});
}
