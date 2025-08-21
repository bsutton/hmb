/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'hmb_database_factory.dart' as local;

class FlutterDatabaseFactory implements local.HMBDatabaseFactory {
  static FlutterDatabaseFactory? instance;

  factory FlutterDatabaseFactory() {
    if (instance == null) {
      instance = FlutterDatabaseFactory._();
      instance!.initDatabaseFactory(isWeb: kIsWeb);
    }

    return instance!;
  }

  FlutterDatabaseFactory._();

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
  Future<Database> openDatabase(
    String path, {
    required OpenDatabaseOptions options,
  }) => databaseFactory.openDatabase(path, options: options);
}
