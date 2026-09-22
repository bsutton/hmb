import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../../database/management/db_utility_test_helper.dart';
import 'utility.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  for (final groupByTask in [true, false]) {
    test('nonbillable time stays free with grouping $groupByTask', () async {
      final job = await createJob(
        DateTime.now(),
        BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.dollars(100),
      );
      final task = await createTask(job, 'Example work');
      final entries = <TimeEntry>[];
      for (var index = 0; index < 3; index++) {
        final entry = TimeEntry.forInsert(
          taskId: task.id,
          startTime: DateTime(2026, 1, 1, 9),
          endTime: DateTime(2026, 1, 1, 10),
          billable: index == 0,
          showOnInvoice: index == 1,
          note: 'Work $index',
        );
        await DaoTimeEntry().insert(entry);
        entries.add(entry);
      }
      final invoice = await createInvoiceForSelectedTasks(
        job,
        await createContact('Example', 'Contact'),
        [task.id],
        groupByTask: groupByTask,
        billBookingFee: false,
      );
      expect(invoice.totalAmount, MoneyEx.dollars(100));
      final lines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
      expect(
        lines.where((line) => line.description.startsWith('No-charge')),
        hasLength(1),
      );
      final shown = (await DaoTimeEntry().getById(entries[1].id))!;
      final hidden = (await DaoTimeEntry().getById(entries[2].id))!;
      expect(shown.billed, isTrue);
      expect(hidden.billed, isFalse);
      expect(await DaoTimeEntry().getByTask(task.id), hasLength(3));
      await expectLater(
        DaoTimeEntry().update(shown.copyWith(billable: true)),
        throwsException,
      );
      final accrued = await DaoTask().getAccruedValueForTask(
        job: job,
        task: task,
        includeBilled: false,
      );
      expect(await accrued.earned, MoneyEx.zero);
    });
  }
}
