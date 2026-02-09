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

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'hmb_database_factory.dart' as local;

class CliDatabaseFactory implements local.HMBDatabaseFactory {
  static CliDatabaseFactory? instance;

  factory CliDatabaseFactory() {
    if (instance == null) {
      instance = CliDatabaseFactory._();
      instance!.initDatabaseFactory();
    }

    return instance!;
  }

  CliDatabaseFactory._();

  void initDatabaseFactory() {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      /// required for non-mobile platforms.
      databaseFactory = databaseFactoryFfi;
    } else if (Platform.isAndroid || Platform.isIOS) {
      /// uses the default factory.
    }
  }

  @override
  Future<Database> openDatabase(
    String path, {
    required OpenDatabaseOptions options,
  }) => databaseFactory.openDatabase(path, options: options);
}
