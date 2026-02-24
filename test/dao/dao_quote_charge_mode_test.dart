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

  test(
    'quote lines use direct-entered charges for unit and total amounts',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(8000, isoCode: 'AUD'),
      );

      final task = Task.forInsert(
        jobId: job.id,
        name: 'Direct charge task',
        description: '',
        status: TaskStatus.awaitingApproval,
      );
      await DaoTask().insert(task);

      await DaoTaskItem().insert(
        TaskItem.forInsert(
          taskId: task.id,
          description: 'Labour item',
          purpose: '',
          itemType: TaskItemType.labour,
          estimatedLabourHours: Fixed.fromNum(2, decimalDigits: 3),
          estimatedLabourCost: Money.fromInt(5000, isoCode: 'AUD'),
          chargeMode: ChargeMode.userDefined,
          totalLineCharge: Money.fromInt(12345, isoCode: 'AUD'),
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
          taskId: task.id,
          description: 'Material item',
          purpose: '',
          itemType: TaskItemType.materialsBuy,
          estimatedMaterialUnitCost: Money.fromInt(1000, isoCode: 'AUD'),
          estimatedMaterialQuantity: Fixed.fromNum(3, decimalDigits: 3),
          chargeMode: ChargeMode.userDefined,
          totalLineCharge: Money.fromInt(4500, isoCode: 'AUD'),
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
      final quote = await DaoQuote().create(
        job,
        InvoiceOptions(
          selectedTaskIds: [task.id],
          billBookingFee: false,
          groupByTask: true,
          contact: contact,
        ),
      );

      final lines = await DaoQuoteLine().getByQuoteId(quote.id);
      final labourLine = lines.firstWhere(
        (line) => line.description == 'Labour',
      );
      final materialLine = lines.firstWhere(
        (line) => line.description == 'Material: Material item',
      );

      expect(labourLine.lineTotal, Money.fromInt(12345, isoCode: 'AUD'));
      expect(
        labourLine.unitCharge,
        labourLine.lineTotal.divideByFixed(labourLine.quantity),
      );

      expect(materialLine.lineTotal, Money.fromInt(4500, isoCode: 'AUD'));
      expect(
        materialLine.unitCharge,
        materialLine.lineTotal.divideByFixed(materialLine.quantity),
      );
    },
  );
}
