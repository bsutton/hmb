import 'package:fixed/fixed.dart';
import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';
import 'package:strings/strings.dart';

import '../entity/entity.g.dart';
import '../ui/invoicing/dialog_select_tasks.dart';
import '../util/exceptions.dart';
import '../util/money_ex.dart';
import 'dao.dart';
import 'dao_quote_line.dart';
import 'dao_quote_line_group.dart';
import 'dao_task.dart';
import 'dao_task_item.dart';

class DaoQuote extends Dao<Quote> {
  @override
  String get tableName => 'quote';

  @override
  Quote fromMap(Map<String, dynamic> map) => Quote.fromMap(map);

  @override
  Future<List<Quote>> getAll({String? orderByClause}) async {
    final db = withoutTransaction();
    return toList(await db.query(tableName, orderBy: 'modified_date desc'));
  }

  Future<List<Quote>> getByJobId(int jobId) async {
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

  Future<List<Quote>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    if (Strings.isBlank(filter)) {
      return getAll(orderByClause: 'modified_date desc');
    }

    return toList(
      await db.rawQuery(
        '''
    SELECT q.*
    FROM quote q
    LEFT JOIN job j ON q.job_id = j.id
    LEFT JOIN customer c ON j.customer_id = c.id
    WHERE q.quote_num LIKE ? 
       OR q.external_quote_id LIKE ?
       OR j.summary LIKE ?
       OR c.name LIKE ?
       OR q.id = ?
    ORDER BY q.modified_date DESC
  ''',
        [
          '%$filter%', // Filter for quote_num
          '%$filter%', // Filter for external_quote_id
          '%$filter%', // Filter for job summary
          '%$filter%', // Filter for customer name
          filter, // filter based on quote id.
        ],
      ),
    );
  }

  Future<List<Quote>> getQuotesWithoutMilestones() async {
    final db = withoutTransaction();
    return toList(
      await db.rawQuery('''
      SELECT q.*
      FROM quote q
      LEFT JOIN milestone m ON q.id = m.quote_id
      WHERE m.id IS NULL
    '''),
    );
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

    // Insert the Quote
    final quote = Quote.forInsert(
      jobId: job.id,
      totalAmount: totalAmount,
      assumption: job.assumption,
    );
    final quoteId = await insert(quote);

    // Add Booking Fee as a quote line
    if (invoiceOptions.billBookingFee &&
        job.bookingFee != null &&
        !job.bookingFee!.isZero) {
      final bookingGroup = QuoteLineGroup.forInsert(
        quoteId: quoteId,
        taskId: null,
        name: 'Booking Fee',
        assumption: '',
      );
      await DaoQuoteLineGroup().insert(bookingGroup);

      final bookingLine = QuoteLine.forInsert(
        quoteId: quoteId,
        quoteLineGroupId: bookingGroup.id,
        description: 'Booking Fee',
        quantity: Fixed.fromInt(100),
        unitCharge: job.bookingFee!,
        lineTotal: job.bookingFee!,
      );
      await DaoQuoteLine().insert(bookingLine);
      totalAmount += job.bookingFee!;
    }

    // Create quote lines and groups for each task
    for (final estimate in estimates) {
      if (!invoiceOptions.selectedTaskIds.contains(estimate.task.id)) {
        continue;
      }

      /// One group for each task.
      QuoteLineGroup? group;
      QuoteLine? line;

      // Labour
      if (!MoneyEx.isZeroOrNull(estimate.estimatedLabourCharge)) {
        /// Labour based billing using estimated effort
        final labourTotal = estimate.estimatedLabourCharge;

        if (!labourTotal.isZero) {
          line = QuoteLine.forInsert(
            quoteId: quoteId,
            description: 'Labour',
            quantity: estimate.estimatedLabourHours,
            unitCharge: job.hourlyRate!,
            lineTotal: labourTotal,
          );
          totalAmount += labourTotal;
        }
      }

      // Group + insert labour line
      if (line != null) {
        group ??= await _createQuoteLineGroup(estimate.task, quoteId);
        await DaoQuoteLine().insert(line.copyWith(quoteLineGroupId: group.id));
      }

      // Materials & Tools
      final items = await DaoTaskItem().getByTask(estimate.task.id);
      for (final item in items.where((i) => !i.billed)) {
        if (item.itemTypeId == TaskItemTypeEnum.labour.id) {
          continue;
        }

        final matTotal = item.calcMaterialCharges(job.billingType);

        group ??= await _createQuoteLineGroup(estimate.task, quoteId);

        final matLine = QuoteLine.forInsert(
          quoteId: quoteId,
          quoteLineGroupId: group.id,
          description: 'Material: ${item.description}',
          quantity: item.estimatedMaterialQuantity!,
          unitCharge: item.estimatedMaterialUnitCost!.plusPercentage(
            item.margin,
          ),
          lineTotal: matTotal,
        );
        await DaoQuoteLine().insert(matLine);
        totalAmount += matTotal;
      }
    }

    // Finalize
    final updated = quote.copyWith(id: quoteId, totalAmount: totalAmount);
    await update(updated);
    return updated;
  }

  Future<QuoteLineGroup> _createQuoteLineGroup(Task task, int quoteId) async {
    // Create quote line group for the task
    final quoteLineGroup = QuoteLineGroup.forInsert(
      quoteId: quoteId,
      name: task.name,
      assumption: task.assumption,
      taskId: task.id,
    );

    await DaoQuoteLineGroup().insert(quoteLineGroup);

    return quoteLineGroup;
  }

  Future<void> recalculateTotal(int quoteId) async {
    final lines = await DaoQuoteLine().getByQuoteId(quoteId);
    var total = MoneyEx.zero;
    for (final line in lines) {
      if (line.lineChargeableStatus == LineChargeableStatus.normal) {
        final lineTotal = line.unitCharge.multiplyByFixed(line.quantity);
        total += lineTotal;
      }
    }
    final quote = await DaoQuote().getById(quoteId);
    final updatedQuote = quote!.copyWith(totalAmount: total);
    await DaoQuote().update(updatedQuote);
  }

  /// Updates the quote's state (and the modified_date).
  Future<int> updateState(
    int quoteId,
    QuoteState newState, {
    Transaction? transaction,
  }) {
    final db = withinTransaction(transaction);
    return db.update(
      tableName,
      {
        'state': newState.name,
        'modified_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [quoteId],
    );
  }

  /// Approve quote
  Future<int> approveQuote(int quoteId, {Transaction? transaction}) {
    final db = withinTransaction(transaction);
    return db.update(
      tableName,
      {
        'state': QuoteState.approved.name,
        'date_approved': DateTime.now().toIso8601String(),
        'modified_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [quoteId],
    );
  }

  /// Reject quote
  Future<int> rejectQuote(int quoteId, {Transaction? transaction}) =>
      updateState(quoteId, QuoteState.rejected, transaction: transaction);

  /// quote sent
  Future<int> markQuoteSent(int quoteId, {Transaction? transaction}) {
    final db = withinTransaction(transaction);
    return db.update(
      tableName,
      {
        'state': QuoteState.sent.name,
        'date_sent': DateTime.now().toIso8601String(),
        'modified_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [quoteId],
    );
  }

  @override
  JuneStateCreator get juneRefresher => QuoteStateNotifier.new;
}

/// Used to notify the UI that the quote has changed.
class QuoteStateNotifier extends JuneState {
  QuoteStateNotifier();
}
