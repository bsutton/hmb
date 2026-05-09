import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('replaces receipt line items', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: MoneyEx.zero,
    );
    final supplier = await _insertSupplier();
    final receipt = Receipt.forInsert(
      receiptDate: DateTime(2026, 5, 2),
      jobId: job.id,
      supplierId: supplier.id,
      totalExcludingTax: MoneyEx.dollars(25),
      tax: MoneyEx.fromInt(250),
      totalIncludingTax: MoneyEx.fromInt(2750),
    );
    await DaoReceipt().insert(receipt);

    await DaoReceiptLineItem().replaceForReceipt(receipt.id, [
      ReceiptLineItem.forInsert(
        receiptId: receipt.id,
        description: 'Timber',
        quantity: 2,
        unitPrice: MoneyEx.fromInt(1250),
        lineTotalExTax: MoneyEx.dollars(25),
        taxAmount: MoneyEx.fromInt(250),
        lineTotalIncTax: MoneyEx.fromInt(2750),
        matchedTaskItemId: null,
        confidence: 91,
        source: 'photo_ocr',
      ),
      ReceiptLineItem.forInsert(
        receiptId: receipt.id,
        description: 'Screws',
        quantity: 1,
        unitPrice: MoneyEx.fromInt(500),
        lineTotalExTax: MoneyEx.fromInt(500),
        taxAmount: MoneyEx.fromInt(50),
        lineTotalIncTax: MoneyEx.fromInt(550),
        matchedTaskItemId: null,
        confidence: 86,
        source: 'photo_ocr',
      ),
    ]);

    final lines = await DaoReceiptLineItem().getByReceiptId(receipt.id);

    expect(lines.map((line) => line.description), ['Timber', 'Screws']);
    expect(lines.first.lineTotalExTax, MoneyEx.dollars(25));
    expect(lines.last.lineTotalExTax, MoneyEx.fromInt(500));
    expect(lines.first.source, 'photo_ocr');
  });
}

Future<Supplier> _insertSupplier() async {
  final supplier = Supplier.forInsert(
    name: 'Receipt Line Supplier',
    businessNumber: '',
    description: '',
    bsb: '',
    accountNumber: '',
    service: '',
  );
  await DaoSupplier().insert(supplier);
  return supplier;
}
