import 'package:fixed/fixed.dart';
import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/job.dart';
import '../entity/quote.dart';
import '../entity/quote_line.dart';
import '../entity/quote_line_group.dart';
import '../entity/task.dart';
import '../util/exceptions.dart';
import '../util/fixed_ex.dart';
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
  Future<List<Quote>> getAll(
      {String? orderByClause, Transaction? transaction}) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps =
        await db.query(tableName, orderBy: 'modified_date desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<Quote>> getByJobId(int jobId, [Transaction? transaction]) async {
    final db = getDb(transaction);
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
    final invoices = await getByJobId(jobId, transaction);

    for (final invoice in invoices) {
      await delete(invoice.id);
    }
  }

  /// Create a quote for the given job.
  Future<Quote> create(Job job, List<int> selectedTaskIds) async {
    final tasks = await DaoTask().getTasksByJob(job.id);

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

    // Add callout fee as a quote line
    if (job.callOutFee != null && !job.callOutFee!.isZero) {
      final quoteLineGroup = QuoteLineGroup.forInsert(
        quoteId: quoteId,
        name: 'Callout Fee',
      );
      await DaoQuoteLineGroup().insert(quoteLineGroup);
      final callOutFeeLine = QuoteLine.forInsert(
        quoteId: quoteId,
        quoteLineGroupId: quoteLineGroup.id,
        description: 'Callout Fee',
        quantity: Fixed.fromInt(100),
        unitPrice: job.callOutFee!,
        lineTotal: job.callOutFee!,
      );
      await DaoQuoteLine().insert(callOutFeeLine);
      totalAmount += job.callOutFee!;
    }

    // Create quote lines and groups for each task
    for (final task in tasks) {
      if (!selectedTaskIds.contains(task.id)) {
        continue;
      }

      /// One group for each task.
      QuoteLineGroup? quoteLineGroup;

      QuoteLine? quoteLine;

      final hourlyRate = await DaoTask().getHourlyRate(task);

      final estimates = await DaoTask().getTaskEstimates(task, hourlyRate);

      if (!MoneyEx.isZeroOrNull(estimates.cost)) {
        /// Cost based billing
        final lineTotal = estimates.cost;

        if (!lineTotal.isZero) {
          quoteLine = QuoteLine.forInsert(
            quoteId: quoteId,
            description: task.name,
            quantity: Fixed.fromInt(100),
            unitPrice: estimates.cost,
            lineTotal: lineTotal,
          );

          totalAmount += lineTotal;
        }
      } else if (!FixedEx.isZeroOrNull(estimates.effortInHours)) {
        /// Labour based billing using estimated effort
        final lineTotal =
            job.hourlyRate!.multiplyByFixed(estimates.effortInHours);

        if (!lineTotal.isZero) {
          quoteLine = QuoteLine.forInsert(
            quoteId: quoteId,
            description: task.name,
            quantity: estimates.effortInHours,
            unitPrice: job.hourlyRate!,
            lineTotal: lineTotal,
          );

          totalAmount += lineTotal;
        }
      }

      if (quoteLine != null) {
        quoteLineGroup ??= await _createQuoteLineGroup(task, quoteId);
        await DaoQuoteLine()
            .insert(quoteLine.copyWith(quoteLineGroupId: quoteLineGroup.id));
      }

      /// Materials based billing
      final checkListItems = await DaoCheckListItem().getByTask(task.id);
      for (final item in checkListItems.where((item) => !item.billed)) {
        final lineTotal = item.estimatedMaterialCost!
            .multiplyByFixed(item.estimatedMaterialQuantity!);
        quoteLineGroup ??= await _createQuoteLineGroup(task, quoteId);

        final quoteLine = QuoteLine.forInsert(
          quoteId: quoteId,
          quoteLineGroupId: quoteLineGroup.id,
          description: 'Material: ${item.description}',
          quantity: item.estimatedMaterialQuantity!,
          unitPrice: item.estimatedMaterialCost!,
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
