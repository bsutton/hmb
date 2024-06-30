import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/invoice.dart';
import '../entity/invoice_line.dart';
import '../entity/invoice_line_group.dart';
import '../entity/job.dart';
import '../util/exceptions.dart';
import '../util/format.dart';
import '../util/money_ex.dart';
import 'dao.dart';
import 'dao_checklist_item.dart';
import 'dao_invoice_line.dart';
import 'dao_invoice_line_group.dart';
import 'dao_task.dart';
import 'dao_time_entry.dart';

class DaoInvoice extends Dao<Invoice> {
  @override
  String get tableName => 'invoice';

  @override
  Invoice fromMap(Map<String, dynamic> map) => Invoice.fromMap(map);

  @override
  Future<List<Invoice>> getAll([Transaction? transaction]) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps =
        await db.query(tableName, orderBy: 'modified_date desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<Invoice>> getByJobId(int jobId,
      [Transaction? transaction]) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps = await db.query(tableName,
        where: 'job_id = ?', whereArgs: [jobId], orderBy: 'id desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    await DaoInvoiceLine().deleteByInvoiceId(id);
    await DaoInvoiceLineGroup().deleteByInvoiceId(id);

    return super.delete(id);
  }

  /// Create an invoice for the given job.
  Future<Invoice> create(Job job, List<int> selectedTaskIds) async {
    final tasks = await DaoTask().getTasksByJob(job);

    if (job.hourlyRate == MoneyEx.zero) {
      throw InvoiceException(
          'Hourly rate must be set for job ${job.description}');
    }

    var totalAmount = MoneyEx.zero;

    // Create invoice
    final invoice = Invoice.forInsert(
      jobId: job.id,
      totalAmount: totalAmount,
    );

    final invoiceId = await DaoInvoice().insert(invoice);

    // Create invoice lines and groups for each task
    for (final task in tasks) {
      if (!selectedTaskIds.contains(task.id)) {
        continue;
      }
      // Create invoice line group for the task
      final invoiceLineGroup = InvoiceLineGroup.forInsert(
        invoiceId: invoiceId,
        name: task.name,
      );

      final invoiceLineGroupId =
          await DaoInvoiceLineGroup().insert(invoiceLineGroup);

      final timeEntries = await DaoTimeEntry().getByTask(task.id);
      for (final timeEntry in timeEntries.where((entry) => !entry.billed)) {
        final duration = timeEntry.duration.inMinutes / 60;
        final lineTotal =
            job.hourlyRate!.multiplyByFixed(Fixed.fromNum(duration));

        if (lineTotal.isZero) {
          continue;
        }

        final invoiceLine = InvoiceLine.forInsert(
          invoiceId: invoiceId,
          invoiceLineGroupId: invoiceLineGroupId,
          description:
              'Labour: ${task.name} on ${formatDate(timeEntry.startTime)}',
          quantity: Fixed.fromNum(duration, scale: 2),
          unitPrice: job.hourlyRate!,
          lineTotal: lineTotal,
        );

        await DaoInvoiceLine().insert(invoiceLine);
        totalAmount += lineTotal;

        // Mark time entry as billed
        await DaoTimeEntry().markAsBilled(timeEntry, invoiceLine.id);
      }

      // Create invoice lines for each checklist item
      final checkListItems = await DaoCheckListItem().getByTask(task);
      for (final item in checkListItems.where((item) => !item.billed)) {
        final lineTotal = item.unitCost.multiplyByFixed(item.quantity);

        final invoiceLine = InvoiceLine.forInsert(
          invoiceId: invoiceId,
          invoiceLineGroupId: invoiceLineGroupId,
          description: 'Material: ${item.description}',
          quantity: item.quantity,
          unitPrice: item.unitCost,
          lineTotal: lineTotal,
        );

        await DaoInvoiceLine().insert(invoiceLine);
        totalAmount += lineTotal;

        // Mark checklist item as billed
        final updatedItem =
            item.copyWith(billed: true, invoiceLineId: invoiceLine.id);
        await DaoCheckListItem().update(updatedItem);
      }
    }

    // Update the invoice total amount
    final updatedInvoice = invoice.copyWith(
      id: invoiceId,
      totalAmount: totalAmount,
    );
    await DaoInvoice().update(updatedInvoice);

    return updatedInvoice;
  }

  @override
  JuneStateCreator get juneRefresher => InvoiceState.new;

  Future<void> recalculateTotal(int invoiceId) async {
    final lines = await DaoInvoiceLine().getByInvoiceId(invoiceId);
    var total = MoneyEx.zero;
    for (final line in lines) {
      final lineTotal = line.unitPrice.multiplyByFixed(line.quantity);
      total += lineTotal;
    }
    final invoice = await DaoInvoice().getById(invoiceId);
    final updatedInvoice = invoice!.copyWith(totalAmount: total);
    await DaoInvoice().update(updatedInvoice);
  }
}

/// Used to notify the UI that the time entry has changed.
class InvoiceState extends JuneState {
  InvoiceState();
}
