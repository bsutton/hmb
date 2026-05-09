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

import 'package:strings/strings.dart';

import '../entity/supplier.dart';
import 'dao.dart';

class DaoSupplier extends Dao<Supplier> {
  static const tableName = 'supplier';
  DaoSupplier() : super(tableName);

  Future<List<Supplier>> getByFilter(String? filter) async {
    final db = withoutTransaction();
    const orderByRecentReceipt = '''
ORDER BY MAX(r.receipt_date) IS NULL,
         MAX(r.receipt_date) DESC,
         MAX(r.modified_date) DESC,
         s.name COLLATE NOCASE
''';

    if (Strings.isBlank(filter)) {
      return toList(
        await db.rawQuery('''
SELECT s.*
  FROM supplier s
  LEFT JOIN receipt r
    ON r.supplier_id = s.id
 GROUP BY s.id
$orderByRecentReceipt
'''),
      );
    }
    final like = '''%$filter%''';
    return toList(
      await db.rawQuery(
        '''
SELECT s.*
  FROM supplier s
  LEFT JOIN receipt r
    ON r.supplier_id = s.id
 WHERE s.name LIKE ?
    OR s.description LIKE ?
    OR s.service LIKE ?
 GROUP BY s.id
$orderByRecentReceipt
''',
        [like, like, like],
      ),
    );
  }

  @override
  Supplier fromMap(Map<String, dynamic> map) => Supplier.fromMap(map);
}
