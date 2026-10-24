import 'package:sqflite_common/sqlite_api.dart';

import '../entity/invoice.dart';
import '../entity/invoice_line.dart';
import '../util/dart/exceptions.dart';
import 'billing_mutation.dart';
import 'dao.dart';

/// Source reservation and document lifecycle changes share one transaction.
class InvoiceLifecycleService {
  Database get _db => DatabaseHelper.instance.database;

  Future<Map<String, Object?>> _invoice(Transaction txn, int id) async {
    final rows = await txn.query('invoice', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) {
      throw InvoiceException('Invoice no longer exists.');
    }
    return rows.single;
  }

  Future<void> _withoutLedger(Transaction txn, int id) async {
    for (final table in [
      'debtor_payment_allocation',
      'credit_allocation',
      'debtor_adjustment',
    ]) {
      if ((await txn.query(
        table,
        where: 'invoice_id = ?',
        whereArgs: [id],
        limit: 1,
      )).isNotEmpty) {
        throw InvoiceException(
          'An invoice with ledger activity cannot be changed.',
        );
      }
    }
  }

  Future<void> _draft(Transaction txn, Map<String, Object?> row) async {
    final invoice = Invoice.fromMap(row);
    if (invoice.sent ||
        invoice.paid ||
        invoice.isUploaded() ||
        invoice.isExternallyDeletedOrVoided) {
      throw InvoiceException('Only an unsent draft can be changed.');
    }
    await _withoutLedger(txn, invoice.id);
    if ((await txn.query(
      'quickbooks_invoice_export',
      where: 'invoice_id = ?',
      whereArgs: [invoice.id],
      limit: 1,
    )).isNotEmpty) {
      throw InvoiceException(
        'Reconcile the QuickBooks export before changing this invoice.',
      );
    }
  }

  Future<void> validateInvoiceEdit(Transaction txn, Invoice next) async {
    final old = Invoice.fromMap(await _invoice(txn, next.id));
    if (old.jobId != next.jobId ||
        old.totalAmount != next.totalAmount ||
        old.billingCustomerId != next.billingCustomerId ||
        old.billingContactId != next.billingContactId ||
        old.dueDate != next.dueDate) {
      await _draft(txn, await _invoice(txn, next.id));
    }
  }

  Future<void> requireDraft(Transaction txn, int invoiceId) async {
    await _draft(txn, await _invoice(txn, invoiceId));
  }

  Future<bool> hasReservedLine(int lineId) async => (await _db.query(
    'billing_allocation',
    where: 'invoice_line_id = ? AND released_date IS NULL',
    whereArgs: [lineId],
    limit: 1,
  )).isNotEmpty;

  Future<void> _releaseLine(Transaction txn, int invoiceId, int lineId) async {
    for (final table in ['time_entry', 'task_item']) {
      await txn.update(
        table,
        {'billed': 0, 'invoice_line_id': null},
        where: 'invoice_line_id = ?',
        whereArgs: [lineId],
      );
    }
    await txn.update(
      'receipt_job_allocation',
      {'invoice_line_id': null},
      where: 'invoice_line_id = ?',
      whereArgs: [lineId],
    );
    final claims = await txn.query(
      'billing_allocation',
      where: 'invoice_id = ? AND invoice_line_id = ? AND released_date IS NULL',
      whereArgs: [invoiceId, lineId],
    );
    for (final claim in claims) {
      if (claim['source_type'] == 'milestone') {
        await txn.update(
          'milestone',
          {'invoice_id': null},
          where: 'id = ? AND invoice_id = ?',
          whereArgs: [claim['source_id'], invoiceId],
        );
      }
    }
    await txn.update(
      'billing_allocation',
      {'released_date': DateTime.now().toIso8601String()},
      where: 'invoice_id = ? AND invoice_line_id = ? AND released_date IS NULL',
      whereArgs: [invoiceId, lineId],
    );
    final line = await txn.query(
      'invoice_line',
      where: 'id = ?',
      whereArgs: [lineId],
    );
    if (line.isNotEmpty && line.single['from_booking_fee'] == 1) {
      final invoice = await _invoice(txn, invoiceId);
      await txn.update(
        'job',
        {'booking_fee_invoiced': 0},
        where: 'id = ?',
        whereArgs: [invoice['job_id']],
      );
    }
  }

  Future<int> deleteDraft(int id, {Transaction? transaction}) {
    Future<int> apply(Transaction txn) async {
      final invoice = await _invoice(txn, id);
      await _draft(txn, invoice);
      final lines = await txn.query(
        'invoice_line',
        where: 'invoice_id = ?',
        whereArgs: [id],
      );
      for (final line in lines) {
        await _releaseLine(txn, id, line['id']! as int);
      }
      await txn.update(
        'milestone',
        {'invoice_id': null},
        where: 'invoice_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'billing_allocation',
        {'released_date': DateTime.now().toIso8601String()},
        where: 'invoice_id = ? AND released_date IS NULL',
        whereArgs: [id],
      );
      await txn.delete(
        'invoice_line',
        where: 'invoice_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'invoice_line_group',
        where: 'invoice_id = ?',
        whereArgs: [id],
      );
      final count = await txn.delete(
        'invoice',
        where: 'id = ?',
        whereArgs: [id],
      );
      await BillingMutation.enqueue(txn, {invoice['job_id']! as int});
      return count;
    }

    return transaction == null ? _db.transaction(apply) : apply(transaction);
  }

  Future<int> deleteLine(int id, {Transaction? transaction}) {
    Future<int> apply(Transaction txn) async {
      final rows = await txn.query(
        'invoice_line',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) {
        return 0;
      }
      final line = rows.single;
      final invoiceId = line['invoice_id']! as int;
      final invoice = await _invoice(txn, invoiceId);
      await _draft(txn, invoice);
      final ambiguous = await txn.query(
        'billing_allocation',
        where:
            'invoice_id = ? AND source_type = ? AND invoice_line_id IS NULL '
            'AND released_date IS NULL',
        whereArgs: [invoiceId, 'milestone'],
      );
      if (ambiguous.isNotEmpty) {
        throw InvoiceException(
          'This legacy milestone has no line mapping. '
          'Delete the whole draft instead.',
        );
      }
      await _releaseLine(txn, invoiceId, id);
      final count = await txn.delete(
        'invoice_line',
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.rawDelete(
        '''
DELETE FROM invoice_line_group WHERE id = ? AND NOT EXISTS
(SELECT 1 FROM invoice_line WHERE invoice_line_group_id = ?)
''',
        [line['invoice_line_group_id'], line['invoice_line_group_id']],
      );
      await txn.rawUpdate(
        '''
UPDATE invoice SET total_amount = (SELECT IFNULL(SUM(line_total), 0)
FROM invoice_line WHERE invoice_id = ?), modified_date = ? WHERE id = ?
''',
        [invoiceId, DateTime.now().toIso8601String(), invoiceId],
      );
      await BillingMutation.enqueue(txn, {invoice['job_id']! as int});
      return count;
    }

    return transaction == null ? _db.transaction(apply) : apply(transaction);
  }

  Future<void> validateLineEdit(Transaction txn, InvoiceLine line) async {
    final invoice = await _invoice(txn, line.invoiceId);
    await _draft(txn, invoice);
    final old = await txn.query(
      'invoice_line',
      where: 'id = ?',
      whereArgs: [line.id],
    );
    if (old.isEmpty) {
      throw InvoiceException('Invoice line no longer exists.');
    }
    final previous = InvoiceLine.fromMap(old.single);
    if (previous.invoiceId != line.invoiceId) {
      await requireDraft(txn, previous.invoiceId);
    }
    final claims = await txn.query(
      'billing_allocation',
      where: 'invoice_line_id = ? AND released_date IS NULL',
      whereArgs: [line.id],
    );
    if (claims.isNotEmpty &&
        (previous.quantity != line.quantity ||
            previous.unitPrice != line.unitPrice ||
            previous.lineTotal != line.lineTotal ||
            previous.status != line.status ||
            previous.taxAmount != line.taxAmount ||
            previous.taxCodeId != line.taxCodeId ||
            previous.taxType != line.taxType ||
            previous.invoiceId != line.invoiceId ||
            previous.fromBookingFee != line.fromBookingFee)) {
      throw InvoiceException(
        'This line reserves billable work. '
        'Remove it and revise the source charge instead.',
      );
    }
  }

  Future<void> voidInvoice(int id, String reason) =>
      _db.transaction((txn) async {
        final row = await _invoice(txn, id);
        final invoice = Invoice.fromMap(row);
        await _withoutLedger(txn, id);
        if (invoice.paid ||
            invoice.isExternallyDeletedOrVoided ||
            reason.trim().isEmpty) {
          throw InvoiceException(
            'A void requires an unpaid active invoice and a reason.',
          );
        }
        // Keep source reservations: voiding is not permission to charge again.
        await txn.update(
          'invoice',
          {
            'external_sync_status': InvoiceExternalSyncStatus.voided.ordinal,
            'void_description': reason.trim(),
            'modified_date': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await BillingMutation.enqueue(txn, {invoice.jobId});
      });

  /// Explicit local rebilling decision, separate from voiding the document.
  Future<void> releaseVoidedInvoice(int id) => _db.transaction((txn) async {
    final row = await _invoice(txn, id);
    final invoice = Invoice.fromMap(row);
    if (!invoice.isExternallyDeletedOrVoided || invoice.isUploaded()) {
      throw InvoiceException(
        'Only a locally voided invoice can release work for rebilling.',
      );
    }
    await _withoutLedger(txn, id);
    if ((await txn.query(
      'quickbooks_invoice_export',
      where: 'invoice_id = ?',
      whereArgs: [id],
      limit: 1,
    )).isNotEmpty) {
      throw InvoiceException(
        'Reconcile the QuickBooks export before releasing this invoice.',
      );
    }
    for (final line in await txn.query(
      'invoice_line',
      where: 'invoice_id = ?',
      whereArgs: [id],
    )) {
      await _releaseLine(txn, id, line['id']! as int);
    }
    await txn.update(
      'milestone',
      {'invoice_id': null},
      where: 'invoice_id = ?',
      whereArgs: [id],
    );
    await txn.update(
      'billing_allocation',
      {'released_date': DateTime.now().toIso8601String()},
      where: 'invoice_id = ? AND released_date IS NULL',
      whereArgs: [id],
    );
    await BillingMutation.enqueue(txn, {invoice.jobId});
  });
}
