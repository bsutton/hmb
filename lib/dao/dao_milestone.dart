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

import '../entity/milestone.dart';
import 'dao.dart';

class DaoMilestone extends Dao<Milestone> {
  static const tableName = 'milestone';

  DaoMilestone() : super(tableName);

  @override
  Milestone fromMap(Map<String, dynamic> map) => Milestone.fromMap(map);

  Future<List<Milestone>> getByQuoteId(int quoteId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'quote_id = ?',
        whereArgs: [quoteId],
        orderBy: 'milestone_number ASC',
      ),
    );
  }

  Future<void> detachFromInvoice(int invoiceId) async {
    await db.update(
      'milestone',
      {'invoice_id': null}, // Set invoice_id to NULL
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
  }
}
