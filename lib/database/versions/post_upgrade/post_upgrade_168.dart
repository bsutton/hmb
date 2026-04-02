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

import 'package:sqflite_common/sqlite_api.dart';

import '../../../dao/system_secret_store.dart';
import '../../../entity/system.dart';

/// Is run after the v168.sql upgrade script is run.
/// Copies legacy integration secrets out of SQLite into secure storage.
Future<void> postv168Upgrade(
  Database db, {
  SystemSecretStore? secretStore,
}) async {
  final rows = await db.query('system', limit: 1);
  if (rows.isEmpty) {
    return;
  }

  final system = System.fromMap(rows.single);
  final store = secretStore ?? SystemSecretStore();
  final migrated = await store.migrateFromDb(system);

  if (migrated) {
    await store.clearLegacyDbCopies(executor: db, systemId: system.id);
  }
}
