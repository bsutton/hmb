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
import '../util/dart/exceptions.dart';
import '../util/dart/money_ex.dart';
import 'dao.dart';
import 'dao_invoice_line.dart';
import 'dao_invoice_line_group.dart';
import 'dao_job.dart';
import 'dao_milestone.dart';

class DaoInvoice extends Dao<Invoice> {
  static const tableName = 'invoice ';
  static const discountGroupName = 'Discounts';
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

  Future<List<Invoice>> getUnsent({int? jobId}) async {
    final db = withoutTransaction();
    final where = jobId == null ? 'sent = 0' : 'sent = 0 AND job_id = ?';
    final args = jobId == null ? <Object?>[] : <Object?>[jobId];
    return toList(
      await db.query(
        tableName,
        where: where,
        whereArgs: args,
        orderBy: 'modified_date desc',
      ),
    );
  }

  Future<bool> hasUnsentForJob(int jobId) async =>
      (await getUnsent(jobId: jobId)).isNotEmpty;

  Future<List<Invoice>> getByFilter(
    String? filter, {
    bool includePaid = true,
  }) async {
    final db = withoutTransaction();
    final paidWhere = includePaid ? '' : ' AND IFNULL(i.paid, 0) = 0';

    if (Strings.isBlank(filter)) {
      return toList(
        await db.rawQuery('''
    SELECT i.*
    FROM invoice i
    LEFT JOIN job j ON i.job_id = j.id
    LEFT JOIN customer c ON j.customer_id = c.id
    WHERE 1 = 1$paidWhere
    ORDER BY i.modified_date DESC
  '''),
      );
    }

    return toList(
      await db.rawQuery(
        '''
    SELECT i.*
    FROM invoice i
    LEFT JOIN job j ON i.job_id = j.id
    LEFT JOIN customer c ON j.customer_id = c.id
    WHERE (
          i.invoice_num LIKE ? 
       OR i.external_invoice_id LIKE ?
       OR j.summary LIKE ?
       OR c.name LIKE ?
    )$paidWhere
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

  Future<List<Invoice>> getUploadedUnpaid() async {
    final db = withoutTransaction();
    return toList(
      await db.rawQuery('''
SELECT *
FROM invoice
WHERE external_invoice_id IS NOT NULL
  AND external_invoice_id != ''
  AND IFNULL(paid, 0) = 0
ORDER BY modified_date DESC
'''),
    );
  }

  Future<void> markPaid(int invoiceId, {DateTime? paidDate}) async {
    final invoice = await getById(invoiceId);
    if (invoice == null) {
      return;
    }
    await update(
      invoice.copyWith(paid: true, paidDate: paidDate ?? DateTime.now()),
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

  Future<List<String>> getEmailsByInvoice(Invoice invoice) =>
      DaoJob().getEmailsByJob(invoice.jobId);

  Future<void> markSent(Invoice invoice) async {
    invoice.sent = true;

    await update(invoice);

    final accounting = AccountingAdaptor.get();
    await accounting.login();

    await accounting.markApproved(invoice);
    await accounting.markSent(invoice);
  }

  Future<InvoiceLine> addDiscountLine({
    required Invoice invoice,
    required Money amount,
    String description = 'Discount',
  }) async {
    if (!amount.isPositive) {
      throw HMBException('Discount amount must be greater than zero.');
    }

    final existingGroups = await DaoInvoiceLineGroup().getByInvoiceId(
      invoice.id,
    );
    InvoiceLineGroup? discountGroup;
    for (final group in existingGroups) {
      if (group.name == discountGroupName) {
        discountGroup = group;
        break;
      }
    }
    discountGroup ??= InvoiceLineGroup.forInsert(
      invoiceId: invoice.id,
      name: discountGroupName,
    );
    if (discountGroup.id == 0) {
      await DaoInvoiceLineGroup().insert(discountGroup);
    }

    final line = InvoiceLine.forInsert(
      invoiceId: invoice.id,
      invoiceLineGroupId: discountGroup.id,
      description: description,
      quantity: Fixed.one,
      unitPrice: -amount,
      lineTotal: -amount,
    );
    await DaoInvoiceLine().insert(line);
    await recalculateTotal(invoice.id);
    return line;
  }
}
