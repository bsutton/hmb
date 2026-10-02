import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:money2/money2.dart';

Future<Job> createJobWithCustomer({
  required BillingType billingType,
  required Money hourlyRate,
  Money? bookingFee,
  String summary = 'Test Job',
  JobStatus status = JobStatus.prospecting,
}) async {
  final unique = DateTime.now().microsecondsSinceEpoch;
  final contactId = await DaoContact().insert(
    Contact.forInsert(
      firstName: 'Pat',
      surname: 'Tester',
      mobileNumber: '0400000000',
      landLine: '',
      officeNumber: '',
      emailAddress: 'pat+$unique@example.com',
    ),
  );
  final customerId = await DaoCustomer().insert(
    Customer.forInsert(
      name: 'Test Customer $unique',
      description: 'Customer for widget tests',
      disbarred: false,
      customerType: CustomerType.residential,
      hourlyRate: hourlyRate,
      billingContactId: contactId,
    ),
  );
  final siteId = await DaoSite().insert(
    Site.forInsert(
      addressLine1: '1 Test St',
      addressLine2: '',
      suburb: 'Testville',
      state: 'TS',
      postcode: '1234',
      accessDetails: null,
    ),
  );

  final jobId = await DaoJob().insert(
    Job.forInsert(
      customerId: customerId,
      summary: summary,
      description: 'Widget test job',
      siteId: siteId,
      contactId: contactId,
      status: status,
      hourlyRate: hourlyRate,
      bookingFee: bookingFee,
      billingType: billingType,
      billingContactId: contactId,
    ),
  );

  return (await DaoJob().getById(jobId))!;
}

/// Pumps frames while allowing database-isolate work to finish in real time.
/// pumpAndSettle alone can return before I/O schedules its next frame.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) =>
    pumpUntilCondition(tester, () => finder.evaluate().isNotEmpty, '$finder');

/// Wait for a background side effect without blocking the widget's fake clock.
Future<void> pumpUntilCondition(
  WidgetTester tester,
  bool Function() complete,
  String description,
) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (complete()) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  fail('Timed out waiting for $description');
}

/// Keep fake-clock continuations moving while real database work is awaited.
/// Awaiting a DAO inside runAsync alone can hold up earlier widget queries
/// whose continuations need a pump before they release the SQLite lock.
Future<T> runAsyncAndPump<T>(
  WidgetTester tester,
  Future<T> Function() action,
) async {
  var complete = false;
  late T result;
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    unawaited(
      Future<T>.sync(action).then<void>(
        (value) {
          result = value;
          complete = true;
        },
        onError: (Object error, StackTrace stack) {
          failure = error;
          failureStack = stack;
          complete = true;
        },
      ),
    );
  });
  // The test framework owns the timeout for this specific future. Continue
  // pumping until it settles rather than treating a fixed frame count as I/O
  // completion (which depends on host load).
  while (!complete) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
  if (failure != null) {
    Error.throwWithStackTrace(failure!, failureStack!);
  }
  return result;
}
