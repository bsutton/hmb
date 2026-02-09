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

import '../entity/milestone.dart';
import '../util/dart/exceptions.dart';
import 'dao.dart';

class DaoMilestone extends Dao<Milestone> {
  static const tableName = 'milestone';

  DaoMilestone() : super(tableName);

  @override
  Milestone fromMap(Map<String, dynamic> map) => Milestone.fromMap(map);

  Future<List<Milestone>> getByQuoteId(
    int quoteId, {
    bool includeVoided = false,
  }) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: includeVoided ? 'quote_id = ?' : 'quote_id = ? AND voided = 0',
        whereArgs: [quoteId],
        orderBy: 'milestone_number ASC',
      ),
    );
  }

  Future<void> voidByQuoteId(int quoteId, {Transaction? transaction}) async {
    final db = withinTransaction(transaction);
    final rows = await db.query(
      tableName,
      columns: ['id', 'invoice_id'],
      where: 'quote_id = ? AND voided = 0',
      whereArgs: [quoteId],
    );

    if (rows.isEmpty) {
      return;
    }

    final hasInvoiced = rows.any((row) => row['invoice_id'] != null);
    if (hasInvoiced) {
      throw InvoiceException(
        'Cannot void milestones with invoices. Void or delete the invoice '
        'first.',
      );
    }

    await db.update(
      tableName,
      {
        'voided': 1,
        'modified_date': DateTime.now().toIso8601String(),
      },
      where: 'quote_id = ? AND voided = 0',
      whereArgs: [quoteId],
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
