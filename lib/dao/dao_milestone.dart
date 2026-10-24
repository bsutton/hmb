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

import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../entity/milestone.dart';
import '../util/dart/exceptions.dart';
import '../util/dart/money_ex.dart';
import 'billing_mutation.dart';
import 'dao.dart';

class DaoMilestone extends Dao<Milestone> {
  static const tableName = 'milestone';

  DaoMilestone() : super(tableName);

  @override
  Milestone fromMap(Map<String, dynamic> map) => Milestone.fromMap(map);

  /// Replace the editable schedule atomically, retaining every reserved slice.
  Future<void> saveSchedule(int quoteId, List<Milestone> schedule) async {
    await db.transaction((txn) async {
      final quote = (await txn.query(
        'quote',
        where: 'id = ?',
        whereArgs: [quoteId],
      )).single;
      final finalClaims = await txn.query(
        'billing_allocation',
        where:
            "source_type = 'quote' AND source_id = ? AND released_date IS NULL",
        whereArgs: [quoteId],
      );
      if (finalClaims.isNotEmpty) {
        throw InvoiceException(
          'The final payment is already reserved or invoiced.',
        );
      }
      final old = (await txn.query(
        'milestone',
        where: 'quote_id = ? AND voided = 0',
        whereArgs: [quoteId],
      )).map(Milestone.fromMap).toList();
      final total = schedule.fold<Money>(
        MoneyEx.zero,
        (sum, milestone) => sum + milestone.paymentAmount,
      );
      if (schedule.any(
            (m) => m.quoteId != quoteId || m.paymentAmount.isNegative,
          ) ||
          total > MoneyEx.fromInt(quote['total_amount']! as int)) {
        throw InvoiceException(
          'Milestones must fit within the agreed quote total.',
        );
      }
      for (final existing in old) {
        final replacement = schedule
            .where((m) => m.id == existing.id)
            .firstOrNull;
        if (existing.invoiceId != null &&
            (replacement == null ||
                replacement.invoiceId != existing.invoiceId ||
                replacement.paymentAmount != existing.paymentAmount ||
                replacement.milestoneDescription !=
                    existing.milestoneDescription)) {
          throw InvoiceException(
            'An invoiced milestone cannot be changed. Refresh the schedule.',
          );
        }
        if (replacement == null) {
          await txn.delete(
            'milestone',
            where: 'id = ?',
            whereArgs: [existing.id],
          );
        }
      }
      final ids = <int>{};
      for (final milestone in schedule) {
        if (old.any((m) => m.id == milestone.id)) {
          if (!ids.add(milestone.id)) {
            throw InvoiceException('Duplicate milestone.');
          }
          final previous = old.singleWhere((m) => m.id == milestone.id);
          if (previous.invoiceId == null && milestone.invoiceId != null) {
            throw InvoiceException('Refresh the milestone schedule.');
          }
          await super.update(milestone, txn);
        } else {
          if (milestone.invoiceId != null) {
            throw InvoiceException('Invalid milestone invoice.');
          }
          await super.insert(milestone, txn);
        }
      }
      await BillingMutation.enqueue(txn, {quote['job_id']! as int});
    });
  }

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
      {'voided': 1, 'modified_date': DateTime.now().toIso8601String()},
      where: 'quote_id = ? AND voided = 0',
      whereArgs: [quoteId],
    );
  }

  Future<void> detachFromInvoice(int invoiceId) async {
    await withoutTransaction().update(
      'milestone',
      {'invoice_id': null}, // Set invoice_id to NULL
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
  }
}
