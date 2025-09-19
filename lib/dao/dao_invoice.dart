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
import 'package:strings/strings.dart';

import '../api/accounting/accounting_adaptor.dart';
import '../entity/entity.g.dart';
import '../util/dart/money_ex.dart';
import 'dao.dart';
import 'dao_invoice_line.dart';
import 'dao_invoice_line_group.dart';
import 'dao_job.dart';
import 'dao_milestone.dart';

class DaoInvoice extends Dao<Invoice> {
  static const tableName = 'invoice ';
  DaoInvoice() : super(tableName);

  @override
  Invoice fromMap(Map<String, dynamic> map) => Invoice.fromMap(map);

  @override
  Future<List<Invoice>> getAll({String? orderByClause}) async {
    final db = withoutTransaction();
    return toList(await db.query(tableName, orderBy: 'modified_date desc'));
  }

  Future<List<Invoice>> getByJobId(int jobId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'job_id = ?',
        whereArgs: [jobId],
        orderBy: 'id desc',
      ),
    );
  }

  Future<List<Invoice>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    if (Strings.isBlank(filter)) {
      return getAll(orderByClause: 'modified_date desc');
    }

    return toList(
      await db.rawQuery(
        '''
    SELECT i.*
    FROM invoice i
    LEFT JOIN job j ON i.job_id = j.id
    LEFT JOIN customer c ON j.customer_id = c.id
    WHERE i.invoice_num LIKE ? 
       OR i.external_invoice_id LIKE ?
       OR j.summary LIKE ?
       OR c.name LIKE ?
    ORDER BY i.modified_date DESC
  ''',
        [
          '%$filter%', // Filter for invoice_num
          '%$filter%', // Filter for external_invoice_id
          '%$filter%', // Filter for job summary
          '%$filter%', // Filter for customer name
        ],
      ),
    );
  }

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    await DaoInvoiceLine().deleteByInvoiceId(id);
    await DaoInvoiceLineGroup().deleteByInvoiceId(id);
    await DaoMilestone().detachFromInvoice(id);

    return super.delete(id);
  }

  Future<void> deleteByJob(int jobId, {Transaction? transaction}) async {
    await withinTransaction(
      transaction,
    ).delete(tableName, where: 'job_id = ?', whereArgs: [jobId]);
  }

  Future<void> recalculateTotal(int invoiceId) async {
    final lines = await DaoInvoiceLine().getByInvoiceId(invoiceId);
    var total = MoneyEx.zero;
    for (final line in lines) {
      final Money lineTotal;
      switch (line.status) {
        case LineChargeableStatus.normal:
          lineTotal = line.unitPrice.multiplyByFixed(line.quantity);
        case LineChargeableStatus.noCharge:
        case LineChargeableStatus.noChargeHidden:
          lineTotal = MoneyEx.zero;
      }
      total += lineTotal;
    }
    final invoice = await DaoInvoice().getById(invoiceId);
    final updatedInvoice = invoice!.copyWith(totalAmount: total);
    await DaoInvoice().update(updatedInvoice);
  }

  Future<List<String>> getEmailsByInvoice(Invoice invoice)  =>
      DaoJob().getEmailsByJob(invoice.jobId);

  Future<void> markSent(Invoice invoice) async {
    invoice.sent = true;

    await update(invoice);

    final accounting = AccountingAdaptor.get();
    await accounting.login();

    await accounting.markApproved(invoice);
    await accounting.markSent(invoice);
  }
}
