import 'package:sqflite/sqflite.dart';

extension Db on Database {
  Future<void> x(String command) async {
    await execute(command);
  }
}
