import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'hmb_database_factory.dart' as local;

class CliDatabaseFactory implements local.HMBDatabaseFactory {
  factory CliDatabaseFactory() {
    if (instance == null) {
      instance = CliDatabaseFactory._();
      instance!.initDatabaseFactory();
    }

    return instance!;
  }

  CliDatabaseFactory._();
  static CliDatabaseFactory? instance;

  void initDatabaseFactory() {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      /// required for non-mobile platforms.
      databaseFactory = databaseFactoryFfi;
    } else if (Platform.isAndroid || Platform.isIOS) {
      /// uses the default factory.
    }
  }

  @override
  Future<Database> openDatabase(String path,
          {required OpenDatabaseOptions options}) async =>
      databaseFactory.openDatabase(path, options: options);
}
