/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/version.dart';
import 'dao.dart';

class DaoVersion extends Dao<Version> {
  Future<void> createTable(Database db, int version) async {
    await db.execute('''
      CREATE TABLE version (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        db_version INTEGER NOT NULL,
        code_version TEXT NOT NULL,
        created_date TEXT DEFAULT CURRENT_TIMESTAMP,
        modified_date TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  @override
  Version fromMap(Map<String, dynamic> map) => Version.fromMap(map);

  Future<Version?> getLatestVersion() async {
    final db = withoutTransaction();
    final result = await db.query(
      tableName,
      orderBy: 'db_version DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return fromMap(result.first);
    }
    return null;
  }

  @override
  String get tableName => 'version';
  @override
  JuneStateCreator get juneRefresher => VersionState.new;
}

/// Used to notify the UI when the version entry changes.
class VersionState extends JuneState {
  VersionState();
}
