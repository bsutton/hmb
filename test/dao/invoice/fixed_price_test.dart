import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/_index.g.dart';
import 'package:hmb/dao/dao_invoice_fixed_price.dart';
import 'package:hmb/entity/_index.g.dart';
import 'package:hmb/util/money_ex.dart';
import 'package:hmb/util/percentage.dart';
import 'package:money2/money2.dart';

import '../../database/management/db_utility_test.dart';
import 'utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });
  test('should create an invoice for a fixed price job with correct estimates',
      () async {
    final now = DateTime.now();
    final job = await createJob(now, BillingType.fixedPrice,
        hourlyRate: MoneyEx.fromInt(5000));
    final task = await createTask(job, 'Task 1');
    final checkList = await DaoCheckList().getByTask(task.id);

    // Insert a labour item with 10 estimated hours at $50/hour
    await insertLabourEstimates(
      checkList,
      MoneyEx.dollars(50), // $50/hour
      Fixed.fromInt(1000), // 10 hours
    );

    // Insert a material buy item with estimated cost $200
    await insertMaterials(
      checkList,
      Fixed.fromNum(1),
      MoneyEx.dollars(200), // $200 estimated cost
      Percentage.twenty, // 20% margin
      (await DaoCheckListItemType()
          .getById(CheckListItemTypeEnum.materialsBuy.id))!,
    );

    // Create invoice for the job
    final invoice = await createFixedPriceInvoice(
        job, 'Complete Job', Percentage.onehundred, null);

    // Verify that the invoice contains both labour and material items
    final invoiceLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    expect(invoiceLines.length, equals(1));

    // Check invoice totals
    expect(invoice.totalAmount,
        MoneyEx.dollars(790)); // $550 (labour) + $240 (material)
  });
}
