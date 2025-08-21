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
ps://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test.dart';
import 'invoice/utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  group('DaoJob Tests', () {
    test('should create a job and retrieve it', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      final retrievedJob = await DaoJob().getById(job.id);
      expect(retrievedJob, isNotNull);
      expect(retrievedJob?.id, equals(job.id));
      expect(retrievedJob?.billingType, equals(BillingType.timeAndMaterial));
      expect(
        retrievedJob?.hourlyRate,
        equals(Money.fromInt(5000, isoCode: 'AUD')),
      );
      expect(
        retrievedJob?.bookingFee,
        equals(Money.fromInt(10000, isoCode: 'AUD')),
      );
    });

    test('should update a job and verify the changes', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      job.hourlyRate = Money.fromInt(7000, isoCode: 'AUD');
      await DaoJob().update(job);

      final retrievedJob = await DaoJob().getById(job.id);
      expect(
        retrievedJob?.hourlyRate,
        equals(Money.fromInt(7000, isoCode: 'AUD')),
      );
    });

    test('should delete a job and verify it is removed', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      await DaoJob().delete(job.id);

      final retrievedJob = await DaoJob().getById(job.id);
      expect(retrievedJob, isNull);
    });

    test('should get all jobs', () async {
      final now = DateTime.now();
      await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );
      await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(7000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(15000, isoCode: 'AUD'),
      );

      final jobs = await DaoJob().getAll();
      expect(jobs.length, equals(2));
    });

    test('should find jobs by name', () async {
      final now = DateTime.now();
      await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );
      await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(7000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(15000, isoCode: 'AUD'),
        summary: 'Special Job',
      );

      final jobs = await DaoJob().getByFilter('Special Job');
      expect(jobs.length, equals(1));
      expect(jobs.first.summary, equals('Special Job'));
    });

    test('should get active jobs', () async {
      final now = DateTime.now();
      await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );
      final job = await createJob(
        now,
        BillingType.fixedPrice,
        hourlyRate: Money.fromInt(7000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(15000, isoCode: 'AUD'),
      );

      job.lastActive = false;
      await DaoJob().update(job);
      final activeJobs = await DaoJob().getActiveJobs(null);
      expect(activeJobs.length, equals(1));
      expect(activeJobs.first.lastActive, isTrue);
    });

    test('should set job as inactive', () async {
      final now = DateTime.now();
      final job = await createJob(
        now,
        BillingType.timeAndMaterial,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
      );

      job.lastActive = false;
      await DaoJob().update(job);

      final retrievedJob = await DaoJob().getById(job.id);
      expect(retrievedJob?.lastActive, isFalse);
    });
  });
}
