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

import '../entity/entity.g.dart';
import '../ui/invoicing/invoice_options.dart';
import '../util/dart/exceptions.dart';
import '../util/dart/money_ex.dart';
import 'dao.g.dart';

class DaoQuote extends Dao<Quote> {
  static const tableName = 'quote';

  DaoQuote() : super(tableName);

  @override
  Quote fromMap(Map<String, dynamic> map) => Quote.fromMap(map);

  @override
  Future<List<Quote>> getAll({
    String? orderByClause,
    Transaction? transaction,
  }) async {
    final db = withinTransaction(transaction);
    return toList(await db.query(tableName, orderBy: 'modified_date desc'));
  }

  Future<List<Quote>> getByJobId(int jobId, {Transaction? transaction}) async {
    final db = withinTransaction(transaction);
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
      LEFT JOIN milestone m ON q.id = m.quote_id AND m.voided = 0
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
    final estimates = await DaoTask().getEstimatesForJob(job);

    if (job.hourlyRate == MoneyEx.zero) {
      throw InvoiceException(
        "Hourly rate must be set for job '${job.summary}'",
      );
    }

    var totalAmount = MoneyEx.zero;
    final insertedLines = <QuoteLine>[];

    // Insert the Quote
    final quote = Quote.forInsert(
      jobId: job.id,
      summary: job.summary,
      description: job.description,
      totalAmount: totalAmount,
      assumption: job.assumption,
      quoteMargin: invoiceOptions.quoteMargin,
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
      insertedLines.add(bookingLine);
      totalAmount += job.bookingFee!;
    }

    // Create quote lines and groups for each task
    for (final estimate in estimates) {
      if (!invoiceOptions.selectedTaskIds.contains(estimate.task.id)) {
        continue;
      }

      final billingType = estimate.task.effectiveBillingType(job.billingType);
      if (billingType != BillingType.fixedPrice) {
        // Quotes should only contain fixed price tasks.
        continue;
      }
      final taskMargin =
          invoiceOptions.taskMargins[estimate.task.id] ?? Percentage.zero;

      /// One group for each task.
      QuoteLineGroup? group;
      final items = await DaoTaskItem().getByTask(estimate.task.id);
      var labourTotal = MoneyEx.zero;

      for (final item in items.where((i) => !i.billed)) {
        if (item.itemType == TaskItemType.labour) {
          labourTotal += _applyTaskMarginOverride(
            item.calcLabourCharges(billingType, job.hourlyRate!),
            taskMargin: taskMargin,
            itemMargin: item.margin,
          );
        }
      }

      // Labour
      if (!labourTotal.isZero) {
        final labourLine = QuoteLine.forInsert(
          quoteId: quoteId,
          description: 'Labour',
          quantity: estimate.estimatedLabourHours,
          unitCharge: _unitChargeForLine(
            labourTotal,
            estimate.estimatedLabourHours,
          ),
          lineTotal: labourTotal,
        );
        group ??= await _createQuoteLineGroup(
          estimate.task,
          quoteId,
          taskMargin,
        );
        final insertedLine = labourLine.copyWith(quoteLineGroupId: group.id);
        await DaoQuoteLine().insert(insertedLine);
        insertedLines.add(insertedLine);
        totalAmount += labourTotal;
      }

      // Materials & Tools
      for (final item in items.where((i) => !i.billed)) {
        if (item.itemType == TaskItemType.labour) {
          continue;
        }

        final matTotal = _applyTaskMarginOverride(
          item.calcMaterialCharges(billingType),
          taskMargin: taskMargin,
          itemMargin: item.margin,
        );

        group ??= await _createQuoteLineGroup(
          estimate.task,
          quoteId,
          taskMargin,
        );

        final matLine = QuoteLine.forInsert(
          quoteId: quoteId,
          quoteLineGroupId: group.id,
          description: 'Material: ${item.description}',
          quantity: item.estimatedMaterialQuantity!,
          unitCharge: _unitChargeForLine(
            matTotal,
            item.estimatedMaterialQuantity!,
          ),
          lineTotal: matTotal,
        );
        await DaoQuoteLine().insert(matLine);
        insertedLines.add(matLine);
        totalAmount += matTotal;
      }
    }

    final quoteMargin = invoiceOptions.quoteMargin;
    if (!quoteMargin.isZero &&
        insertedLines.isNotEmpty &&
        !totalAmount.isZero) {
      totalAmount = await _applyQuoteMarginAcrossLines(
        insertedLines,
        quoteMargin,
        baseTotal: totalAmount,
      );
    }

    // Finalize
    final updated = quote.copyWith(totalAmount: totalAmount);
    await update(updated);
    return updated;
  }

  Future<List<String>> getEmailsByQuote(Quote quote) =>
      DaoJob().getEmailsByJob(quote.jobId);

  Future<QuoteLineGroup> _createQuoteLineGroup(
    Task task,
    int quoteId,
    Percentage taskMargin,
  ) async {
    // Create quote line group for the task
    final quoteLineGroup = QuoteLineGroup.forInsert(
      quoteId: quoteId,
      name: task.name,
      description: task.description,
      assumption: task.assumption,
      taskMargin: taskMargin,
      taskId: task.id,
    );

    await DaoQuoteLineGroup().insert(quoteLineGroup);

    return quoteLineGroup;
  }

  Money _unitChargeForLine(Money lineTotal, Fixed quantity) {
    if (quantity.isZero) {
      return MoneyEx.zero;
    }
    return lineTotal.divideByFixed(quantity);
  }

  Money _applyTaskMarginOverride(
    Money baseCharge, {
    required Percentage taskMargin,
    required Percentage itemMargin,
  }) {
    if (baseCharge.isZero || !itemMargin.isZero || taskMargin.isZero) {
      return baseCharge;
    }
    return baseCharge.plusPercentage(taskMargin);
  }

  Future<Money> _applyQuoteMarginAcrossLines(
    List<QuoteLine> lines,
    Percentage quoteMargin, {
    required Money baseTotal,
  }) async {
    final marginAmount = baseTotal.plusPercentage(quoteMargin) - baseTotal;
    var remainder = marginAmount.minorUnits.toInt();
    final baseMinorUnits = baseTotal.minorUnits.toInt();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final extraMinorUnits = i == lines.length - 1
          ? remainder
          : (marginAmount.minorUnits.toInt() *
                    line.lineTotal.minorUnits.toInt()) ~/
                baseMinorUnits;

      remainder -= extraMinorUnits;

      final updatedLineTotal =
          line.lineTotal + MoneyEx.fromInt(extraMinorUnits);
      final updated = line.copyWith(
        unitCharge: _unitChargeForLine(updatedLineTotal, line.quantity),
        lineTotal: updatedLineTotal,
      );
      await DaoQuoteLine().update(updated);
      lines[i] = updated;
    }

    return baseTotal + marginAmount;
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
  Future<int> rejectQuote(int quoteId, {Transaction? transaction}) async {
    await DaoMilestone().voidByQuoteId(quoteId, transaction: transaction);
    return updateState(quoteId, QuoteState.rejected, transaction: transaction);
  }

  /// Withdraw quote by business
  Future<int> withdrawQuote(int quoteId, {Transaction? transaction}) async {
    await DaoMilestone().voidByQuoteId(quoteId, transaction: transaction);
    return updateState(quoteId, QuoteState.withdrawn, transaction: transaction);
  }

  Future<void> rejectByJob(int jobId, {Transaction? transaction}) async {
    final quotes = await getByJobId(jobId, transaction: transaction);
    for (final quote in quotes) {
      if (quote.state != QuoteState.rejected) {
        await rejectQuote(quote.id, transaction: transaction);
      }
    }
  }

  /// quote sent
  Future<int> markQuoteSent(int quoteId, {Transaction? transaction}) async {
    final db = withinTransaction(transaction);
    await db.update(
      tableName,
      {
        'state': QuoteState.sent.name,
        'date_sent': DateTime.now().toIso8601String(),
        'modified_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [quoteId],
    );

    final job = await DaoJob().getByQuoteId(quoteId);
    await DaoJob().markAwaitingApproval(job!);

    return quoteId;
  }
}
