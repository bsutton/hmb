import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'hmb_database_factory.dart' as local;

class FlutterDatabaseFactory implements local.HMBDatabaseFactory {
  factory FlutterDatabaseFactory() {
    if (instance == null) {
      instance = FlutterDatabaseFactory._();
      instance!.initDatabaseFactory(isWeb: kIsWeb);
    }

    return instance!;
  }

  FlutterDatabaseFactory._();
  static FlutterDatabaseFactory? instance;

  void initDatabaseFactory({required bool isWeb}) {
    if (isWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        /// required for non-mobile platforms.
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } else if (Platform.isAndroid || Platform.isIOS) {
        /// uses the default factory.
      }
    }
  }

  @override
  Future<Database> openDatabase(String path,
          {required OpenDatabaseOptions options}) async =>
      databaseFactory.openDatabase(path, options: options);
}
