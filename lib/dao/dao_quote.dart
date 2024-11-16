import 'package:fixed/fixed.dart';
import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/_index.g.dart';
import '../invoicing/dialog_select_tasks.dart';
import '../util/exceptions.dart';
import '../util/money_ex.dart';
import 'dao.dart';
import 'dao_checklist_item.dart';
import 'dao_quote_line.dart';
import 'dao_quote_line_group.dart';
import 'dao_task.dart';

class DaoQuote extends Dao<Quote> {
  @override
  String get tableName => 'quote';

  @override
  Quote fromMap(Map<String, dynamic> map) => Quote.fromMap(map);

  @override
  Future<List<Quote>> getAll({String? orderByClause}) async {
    final db = withoutTransaction();
    final List<Map<String, dynamic>> maps =
        await db.query(tableName, orderBy: 'modified_date desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<Quote>> getByJobId(int jobId) async {
    final db = withoutTransaction();
    final List<Map<String, dynamic>> maps = await db.query(tableName,
        where: 'job_id = ?', whereArgs: [jobId], orderBy: 'id desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    await DaoQuoteLine().deleteByQuoteId(id);
    await DaoQuoteLineGroup().deleteByQuoteId(id);

    return super.delete(id);
  }

  Future<void> deleteByJob(int jobId, {Transaction? transaction}) async {
    final invoices = await getByJobId(jobId);

    for (final invoice in invoices) {
      await delete(invoice.id, transaction);
    }
  }

  /// Create a quote for the given job.
  Future<Quote> create(Job job, InvoiceOptions invoiceOptions) async {
    final estimates = await DaoTask().getEstimatesForJob(job.id);

    if (job.hourlyRate == MoneyEx.zero) {
      throw InvoiceException('Hourly rate must be set for job ${job.summary}');
    }

    var totalAmount = MoneyEx.zero;

    // Create quote
    final quote = Quote.forInsert(
      jobId: job.id,
      totalAmount: totalAmount,
    );

    final quoteId = await DaoQuote().insert(quote);

    // Add Booking Fee as a quote line
    if (job.bookingFee != null && !job.bookingFee!.isZero) {
      final quoteLineGroup = QuoteLineGroup.forInsert(
        quoteId: quoteId,
        name: 'Booking Fee',
      );
      await DaoQuoteLineGroup().insert(quoteLineGroup);
      final bookingFeeLine = QuoteLine.forInsert(
        quoteId: quoteId,
        quoteLineGroupId: quoteLineGroup.id,
        description: 'Booking Fee',
        quantity: Fixed.fromInt(100),
        unitPrice: job.bookingFee!,
        lineTotal: job.bookingFee!,
      );
      await DaoQuoteLine().insert(bookingFeeLine);
      totalAmount += job.bookingFee!;
    }

    // Create quote lines and groups for each task
    for (final estimate in estimates) {
      if (!invoiceOptions.selectedTaskIds.contains(estimate.task.id)) {
        continue;
      }

      /// One group for each task.
      QuoteLineGroup? quoteLineGroup;

      QuoteLine? quoteLine;

      if (!MoneyEx.isZeroOrNull(estimate.estimatedLabourCharge)) {
        /// Labour based billing using estimated effort
        final lineTotal = estimate.estimatedLabourCharge;

        if (!lineTotal.isZero) {
          quoteLine = QuoteLine.forInsert(
            quoteId: quoteId,
            description: 'Labour',
            quantity: estimate.estimatedLabour,
            unitPrice: job.hourlyRate!,
            lineTotal: lineTotal,
          );

          totalAmount += lineTotal;
        }
      }

      if (quoteLine != null) {
        quoteLineGroup ??= await _createQuoteLineGroup(estimate.task, quoteId);
        await DaoQuoteLine()
            .insert(quoteLine.copyWith(quoteLineGroupId: quoteLineGroup.id));
      }

      /// Materials based billing
      final checkListItems =
          await DaoCheckListItem().getByTask(estimate.task.id);
      for (final item in checkListItems.where((item) => !item.billed)) {
        /// Labour is already accounted for in the above labour costs.
        if (item.itemTypeId == CheckListItemTypeEnum.labour.id) {
          continue;
        }
        final lineTotal = item.estimatedMaterialUnitCost!
            .multiplyByFixed(item.estimatedMaterialQuantity!);
        quoteLineGroup ??= await _createQuoteLineGroup(estimate.task, quoteId);

        final quoteLine = QuoteLine.forInsert(
          quoteId: quoteId,
          quoteLineGroupId: quoteLineGroup.id,
          description: 'Material: ${item.description}',
          quantity: item.estimatedMaterialQuantity!,
          unitPrice: item.estimatedMaterialUnitCost!,
          lineTotal: lineTotal,
        );

        await DaoQuoteLine().insert(quoteLine);
        totalAmount += lineTotal;
      }
    }

    // Update the quote total amount
    final updatedQuote = quote.copyWith(
      id: quoteId,
      totalAmount: totalAmount,
    );
    await DaoQuote().update(updatedQuote);

    return updatedQuote;
  }

  Future<QuoteLineGroup> _createQuoteLineGroup(Task task, int quoteId) async {
    // Create quote line group for the task
    final quoteLineGroup = QuoteLineGroup.forInsert(
      quoteId: quoteId,
      name: task.name,
    );

    await DaoQuoteLineGroup().insert(quoteLineGroup);

    return quoteLineGroup;
  }

  @override
  JuneStateCreator get juneRefresher => QuoteState.new;

  Future<void> recalculateTotal(int quoteId) async {
    final lines = await DaoQuoteLine().getByQuoteId(quoteId);
    var total = MoneyEx.zero;
    for (final line in lines) {
      final lineTotal = line.unitPrice.multiplyByFixed(line.quantity);
      total += lineTotal;
    }
    final quote = await DaoQuote().getById(quoteId);
    final updatedQuote = quote!.copyWith(totalAmount: total);
    await DaoQuote().update(updatedQuote);
  }
}

/// Used to notify the UI that the quote has changed.
class QuoteState extends JuneState {
  QuoteState();
}
