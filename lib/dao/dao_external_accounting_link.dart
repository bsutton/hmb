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

import '../entity/entity.g.dart';
import 'dao.dart';

class DaoExternalAccountingLink extends Dao<ExternalAccountingLink> {
  static const tableName = 'external_accounting_link';
  DaoExternalAccountingLink() : super(tableName);

  @override
  ExternalAccountingLink fromMap(Map<String, dynamic> map) =>
      ExternalAccountingLink.fromMap(map);

  Future<ExternalAccountingLink?> getByLocalEntity({
    required String provider,
    required String entityType,
    required int localId,
  }) async {
    final db = withoutTransaction();
    final rows = await db.query(
      tableName,
      where: 'provider = ? AND entity_type = ? AND local_id = ?',
      whereArgs: [provider, entityType, localId],
    );
    return rows.isEmpty ? null : fromMap(rows.first);
  }
}
