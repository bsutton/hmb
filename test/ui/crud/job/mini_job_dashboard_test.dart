@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/job/mini_job_dashboard.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('task dashlet value shows open and completed counts', () {
    final value = taskDashletValue([
      _task(TaskStatus.awaitingApproval),
      _task(TaskStatus.inProgress),
      _task(TaskStatus.completed),
      _task(TaskStatus.onHold),
      _task(TaskStatus.cancelled),
    ]);

    expect(value.value, '2/1');
  });

  test('job invoice dashlet counts paid invoices', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Paid invoice dashlet job',
    );

    await _insertInvoice(job, paid: true, invoiceNum: 'INV-PAID-1');
    await _insertInvoice(job, paid: true, invoiceNum: 'INV-PAID-2');

    final value = await jobInvoiceDashletValue(job);

    expect(value.value, 2);
  });
}

Task _task(TaskStatus status) => Task.forInsert(
  jobId: 1,
  name: status.name,
  description: '',
  status: status,
);

Future<void> _insertInvoice(
  Job job, {
  required bool paid,
  required String invoiceNum,
}) async {
  final invoice = Invoice.forInsert(
    jobId: job.id,
    dueDate: LocalDate.today(),
    totalAmount: Money.fromInt(1000, isoCode: 'AUD'),
    billingContactId: job.billingContactId,
    paid: paid,
    paidDate: paid ? DateTime.now() : null,
  );
  await DaoInvoice().insert(invoice);
  await DaoInvoice().update(invoice.copyWith(invoiceNum: invoiceNum));
}
