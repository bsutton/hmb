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

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/exceptions.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import 'invoice/utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  group('Milestone voiding', () {
    test('voidByQuoteId marks milestones voided and hides them by default',
        () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      final quote = Quote.forInsert(
        jobId: job.id,
        summary: 'Quote',
        description: 'Quote description',
        totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
        state: QuoteState.approved,
      );
      await DaoQuote().insert(quote);

      final milestone = Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: 1,
        paymentAmount: Money.fromInt(25000, isoCode: 'AUD'),
        paymentPercentage: Percentage.fromInt(100),
        milestoneDescription: 'Milestone 1',
      );
      await DaoMilestone().insert(milestone);

      await DaoMilestone().voidByQuoteId(quote.id);

      final active = await DaoMilestone().getByQuoteId(quote.id);
      expect(active, isEmpty);

      final all =
          await DaoMilestone().getByQuoteId(quote.id, includeVoided: true);
      expect(all.length, equals(1));
      expect(all.first.voided, isTrue);
    });

    test('voidByQuoteId throws when any milestone has an invoice', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      final quote = Quote.forInsert(
        jobId: job.id,
        summary: 'Quote',
        description: 'Quote description',
        totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
        state: QuoteState.approved,
      );
      await DaoQuote().insert(quote);

      final milestone = Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: 1,
        paymentAmount: Money.fromInt(25000, isoCode: 'AUD'),
        paymentPercentage: Percentage.fromInt(100),
        milestoneDescription: 'Milestone 1',
        invoiceId: 123,
      );
      await DaoMilestone().insert(milestone);

      expect(
        () => DaoMilestone().voidByQuoteId(quote.id),
        throwsA(isA<InvoiceException>()),
      );
    });
  });

  group('Quote/job rejection with milestones', () {
    test('rejectQuote voids milestones', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      final quote = Quote.forInsert(
        jobId: job.id,
        summary: 'Quote',
        description: 'Quote description',
        totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
        state: QuoteState.approved,
      );
      await DaoQuote().insert(quote);

      final milestone = Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: 1,
        paymentAmount: Money.fromInt(25000, isoCode: 'AUD'),
        paymentPercentage: Percentage.fromInt(100),
        milestoneDescription: 'Milestone 1',
      );
      await DaoMilestone().insert(milestone);

      await DaoQuote().rejectQuote(quote.id);

      final reloadedQuote = await DaoQuote().getById(quote.id);
      expect(reloadedQuote?.state, equals(QuoteState.rejected));

      final all =
          await DaoMilestone().getByQuoteId(quote.id, includeVoided: true);
      expect(all.first.voided, isTrue);
    });

    test('rejecting a job rejects all quotes and voids milestones', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      final quote = Quote.forInsert(
        jobId: job.id,
        summary: 'Quote',
        description: 'Quote description',
        totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
        state: QuoteState.approved,
      );
      await DaoQuote().insert(quote);

      final milestone = Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: 1,
        paymentAmount: Money.fromInt(25000, isoCode: 'AUD'),
        paymentPercentage: Percentage.fromInt(100),
        milestoneDescription: 'Milestone 1',
      );
      await DaoMilestone().insert(milestone);

      job.status = JobStatus.rejected;
      await DaoJob().update(job);

      final reloadedQuote = await DaoQuote().getById(quote.id);
      expect(reloadedQuote?.state, equals(QuoteState.rejected));

      final all =
          await DaoMilestone().getByQuoteId(quote.id, includeVoided: true);
      expect(all.first.voided, isTrue);
    });

    test('rejecting a job fails when milestones are invoiced', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      final quote = Quote.forInsert(
        jobId: job.id,
        summary: 'Quote',
        description: 'Quote description',
        totalAmount: Money.fromInt(25000, isoCode: 'AUD'),
        state: QuoteState.approved,
      );
      await DaoQuote().insert(quote);

      final milestone = Milestone.forInsert(
        quoteId: quote.id,
        milestoneNumber: 1,
        paymentAmount: Money.fromInt(25000, isoCode: 'AUD'),
        paymentPercentage: Percentage.fromInt(100),
        milestoneDescription: 'Milestone 1',
        invoiceId: 123,
      );
      await DaoMilestone().insert(milestone);

      job.status = JobStatus.rejected;
      expect(() => DaoJob().update(job), throwsA(isA<InvoiceException>()));
    });
  });
}
