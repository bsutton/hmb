import 'package:hmb/entity/job.dart';
import 'package:hmb/entity/job_status.dart';
import 'package:hmb/util/flutter/app_title.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

void main() {
  group('formatAppTitle', () {
    test('returns page title when there is no active job', () {
      expect(formatAppTitle('Dashboard'), 'Dashboard');
    });

    test('appends active job id when active job exists', () {
      final job = Job.forInsert(
        customerId: 1,
        siteId: 1,
        contactId: 1,
        billingContactId: 1,
        summary: 'Test',
        description: 'Test desc',
        status: JobStatus.inProgress,
        hourlyRate: Money.fromInt(10000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(0, isoCode: 'AUD'),
      )..id = 42;

      expect(formatAppTitle('Dashboard', activeJob: job), 'Dashboard [#42]');
    });
  });
}
