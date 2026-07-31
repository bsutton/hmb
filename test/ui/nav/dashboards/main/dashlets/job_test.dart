import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/nav/dashboards/main/dashlets/job.dart';
import 'package:money2/money2.dart';

void main() {
  test('job dashlet counts current non-stock jobs only', () {
    final value = JobsDashlet.valueForJobs([
      _job(status: JobStatus.scheduled),
      _job(status: JobStatus.inProgress),
      _job(status: JobStatus.toBeScheduled),
      _job(status: JobStatus.scheduled, billingType: BillingType.nonBillable),
      _job(status: JobStatus.completed),
      _job(status: JobStatus.scheduled, isStock: true),
    ]);

    expect(value.value, '3/1');
  });
}

Job _job({
  required JobStatus status,
  BillingType billingType = BillingType.timeAndMaterial,
  bool isStock = false,
}) => Job.forInsert(
  customerId: 1,
  summary: 'Job',
  description: '',
  siteId: null,
  contactId: null,
  status: status,
  hourlyRate: Money.fromInt(0, isoCode: 'AUD'),
  bookingFee: null,
  billingContactId: null,
  billingType: billingType,
  isStock: isStock,
);
