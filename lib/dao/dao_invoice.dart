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
    bool includePaid = false,
    DateTime? paidSince,
    bool includeDeletedOrVoided = false,
  }) async {
    final db = withoutTransaction();
    final where = <String>[];
    final whereArgs = <Object?>[];

    if (!includeDeletedOrVoided) {
      where.add(
        'IFNULL(i.external_sync_status, 0) NOT IN ('
        '${InvoiceExternalSyncStatus.deleted.ordinal}, '
        '${InvoiceExternalSyncStatus.voided.ordinal})',
      );
    }

    if (!includePaid) {
      where.add('IFNULL(i.paid, 0) = 0');
    } else if (paidSince != null) {
      where.add('''
(IFNULL(i.paid, 0) = 0
 OR (IFNULL(i.paid, 0) = 1 AND i.paid_date >= ?))
''');
      whereArgs.add(paidSince.toIso8601String());
    }

    if (Strings.isNotBlank(filter)) {
      where.add('''
(
      i.invoice_num LIKE ?
   OR i.external_invoice_id LIKE ?
   OR CAST(i.id AS TEXT) LIKE ?
   OR CAST(j.id AS TEXT) LIKE ?
   OR j.summary LIKE ?
   OR c.name LIKE ?
   OR bill.firstName LIKE ?
   OR bill.surname LIKE ?
   OR TRIM(bill.firstName || ' ' || bill.surname) LIKE ?
   OR jobContact.firstName LIKE ?
   OR jobContact.surname LIKE ?
   OR TRIM(jobContact.firstName || ' ' || jobContact.surname) LIKE ?
)
''');
      whereArgs.addAll([
        '%$filter%',
        '%$filter%',
        '%$filter%',
        '%$filter%',
        '%$filter%',
        '%$filter%',
        '%$filter%',
        '%$filter%',
        '%$filter%',
        '%$filter%',
        '%$filter%',
        '%$filter%',
      ]);
    }

    final whereClause = where.isEmpty ? '' : "WHERE ${where.join(' AND ')}";

    return toList(
      await db.rawQuery('''
    SELECT i.*
    FROM invoice i
    LEFT JOIN job j ON i.job_id = j.id
    LEFT JOIN customer c ON j.customer_id = c.id
    LEFT JOIN contact bill ON i.billing_contact_id = bill.id
    LEFT JOIN contact jobContact ON j.contact_id = jobContact.id
    $whereClause
    ORDER BY
      CASE WHEN IFNULL(i.paid, 0) = 0 THEN 0 ELSE 1 END ASC,
      CASE
        WHEN IFNULL(i.paid, 0) = 0 THEN IFNULL(i.due_date, i.created_date)
        ELSE NULL
      END ASC,
      i.modified_date DESC
''', whereArgs),
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
  AND IFNULL(external_sync_status, 0) NOT IN (
    ${InvoiceExternalSyncStatus.deleted.ordinal},
    ${InvoiceExternalSyncStatus.voided.ordinal}
  )
ORDER BY modified_date DESC
'''),
    );
  }

  Future<void> markPaidManually(int invoiceId, {DateTime? paidDate}) async {
    final invoice = await getById(invoiceId);
    if (invoice == null) {
      return;
    }
    await update(
      invoice.copyWith(
        paid: true,
        paidDate: paidDate ?? DateTime.now(),
        paymentSource: InvoicePaymentSource.manual,
      ),
    );
  }

  Future<void> markPaidFromXero(int invoiceId, {DateTime? paidDate}) async {
    final invoice = await getById(invoiceId);
    if (invoice == null) {
      return;
    }
    await update(
      invoice.copyWith(
        paid: true,
        paidDate: paidDate ?? DateTime.now(),
        paymentSource: InvoicePaymentSource.xero,
        externalSyncStatus: InvoiceExternalSyncStatus.linked,
      ),
    );
  }

  Future<void> updateExternalSyncStatus(
    int invoiceId,
    InvoiceExternalSyncStatus externalSyncStatus,
  ) async {
    final invoice = await getById(invoiceId);
    if (invoice == null) {
      return;
    }
    final paymentSource =
        invoice.isUploaded() ||
            externalSyncStatus != InvoiceExternalSyncStatus.none
        ? InvoicePaymentSource.xero
        : invoice.paymentSource;
    await update(
      invoice.copyWith(
        externalSyncStatus: externalSyncStatus,
        paymentSource: paymentSource,
      ),
    );
  }

  Future<void> markManagedByXero(
    int invoiceId, {
    required String invoiceNum,
    required String externalInvoiceId,
  }) async {
    final invoice = await getById(invoiceId);
    if (invoice == null) {
      return;
    }
    await update(
      invoice.copyWith(
        invoiceNum: invoiceNum,
        externalInvoiceId: externalInvoiceId,
        paymentSource: InvoicePaymentSource.xero,
        externalSyncStatus: InvoiceExternalSyncStatus.linked,
      ),
    );
  }

  Future<void> convertToManualTracking(int invoiceId) async {
    final invoice = await getById(invoiceId);
    if (invoice == null) {
      return;
    }
    await update(invoice.copyWith(paymentSource: InvoicePaymentSource.manual));
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
