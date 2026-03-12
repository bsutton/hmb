import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/ui/invoicing/invoice_options.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('amendQuote creates replacement quote and rejects original', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: Money.fromInt(8000, isoCode: 'AUD'),
    );

    final task1 = Task.forInsert(
      jobId: job.id,
      name: 'Task 1',
      description: 'Original task',
      status: TaskStatus.awaitingApproval,
    );
    await DaoTask().insert(task1);

    final task2 = Task.forInsert(
      jobId: job.id,
      name: 'Task 2',
      description: 'New task',
      status: TaskStatus.awaitingApproval,
    );
    await DaoTask().insert(task2);

    await DaoTaskItem().insert(
      TaskItem.forInsert(
        taskId: task1.id,
        description: 'Task 1 material',
        purpose: '',
        itemType: TaskItemType.materialsBuy,
        estimatedMaterialUnitCost: Money.fromInt(1000, isoCode: 'AUD'),
        estimatedMaterialQuantity: Fixed.fromInt(1),
        chargeMode: ChargeMode.userDefined,
        totalLineCharge: Money.fromInt(1000, isoCode: 'AUD'),
        margin: Percentage.zero,
        measurementType: MeasurementType.length,
        dimension1: Fixed.zero,
        dimension2: Fixed.zero,
        dimension3: Fixed.zero,
        units: Units.m,
        url: '',
        labourEntryMode: LabourEntryMode.hours,
      ),
    );

    await DaoTaskItem().insert(
      TaskItem.forInsert(
        taskId: task2.id,
        description: 'Task 2 material',
        purpose: '',
        itemType: TaskItemType.materialsBuy,
        estimatedMaterialUnitCost: Money.fromInt(2000, isoCode: 'AUD'),
        estimatedMaterialQuantity: Fixed.fromInt(1),
        chargeMode: ChargeMode.userDefined,
        totalLineCharge: Money.fromInt(2000, isoCode: 'AUD'),
        margin: Percentage.zero,
        measurementType: MeasurementType.length,
        dimension1: Fixed.zero,
        dimension2: Fixed.zero,
        dimension3: Fixed.zero,
        units: Units.m,
        url: '',
        labourEntryMode: LabourEntryMode.hours,
      ),
    );

    final contact = (await DaoContact().getById(job.contactId))!;
    final originalQuote = await DaoQuote().create(
      job,
      InvoiceOptions(
        selectedTaskIds: [task1.id],
        billBookingFee: false,
        groupByTask: true,
        contact: contact,
      ),
    );

    final amendedQuote = await DaoQuote().amendQuote(
      quoteId: originalQuote.id,
      invoiceOptions: InvoiceOptions(
        selectedTaskIds: [task2.id],
        billBookingFee: false,
        groupByTask: true,
        contact: contact,
      ),
    );

    final reloadedOriginal = await DaoQuote().getById(originalQuote.id);
    expect(reloadedOriginal?.state, QuoteState.rejected);
    expect(amendedQuote.id, isNot(originalQuote.id));
    expect(amendedQuote.state, QuoteState.reviewing);

    final groups = await DaoQuoteLineGroup().getByQuoteId(amendedQuote.id);
    expect(groups.any((group) => group.taskId == task2.id), isTrue);
    expect(groups.any((group) => group.taskId == task1.id), isFalse);
  });
}
