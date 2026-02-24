import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/exceptions.dart';
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

  test('linking a tool receipt photo creates and links a receipt', () async {
    final stockJob = await _ensureStockJob();
    final supplier = Supplier.forInsert(
      name: 'Tool Supplier',
      businessNumber: '',
      description: '',
      bsb: '',
      accountNumber: '',
      service: '',
    );
    await DaoSupplier().insert(supplier);

    final tool = Tool.forInsert(
      name: 'Drill',
      supplierId: supplier.id,
      datePurchased: DateTime.now(),
      cost: Money.fromInt(12500, isoCode: 'AUD'),
    );
    await DaoTool().insert(tool);

    final photo = Photo.forInsert(
      parentId: tool.id,
      parentType: ParentType.tool,
      filename: 'tool-receipt.jpg',
      comment: 'Receipt Photo',
    );
    await DaoPhoto().insert(photo);

    final withReceiptPhoto = tool.copyWith(receiptPhotoId: photo.id);
    await DaoTool().update(withReceiptPhoto);

    final linked = await DaoTool().ensureReceiptLink(withReceiptPhoto);
    expect(linked.receiptId, isNotNull);

    final receipt = await DaoReceipt().getById(linked.receiptId);
    expect(receipt, isNotNull);
    expect(receipt!.jobId, stockJob.id);
    expect(receipt.supplierId, supplier.id);
    expect(receipt.totalIncludingTax, Money.fromInt(12500, isoCode: 'AUD'));

    final reloadedPhoto = await DaoPhoto().getById(photo.id);
    expect(reloadedPhoto, isNotNull);
    expect(reloadedPhoto!.parentType, ParentType.receipt);
    expect(reloadedPhoto.parentId, linked.receiptId);
  });

  test('cannot delete receipt while linked to a tool', () async {
    final supplier = Supplier.forInsert(
      name: 'Delete Guard Supplier',
      businessNumber: '',
      description: '',
      bsb: '',
      accountNumber: '',
      service: '',
    );
    await DaoSupplier().insert(supplier);

    final stockJob = await _ensureStockJob();
    final receipt = Receipt.forInsert(
      receiptDate: DateTime.now(),
      jobId: stockJob.id,
      supplierId: supplier.id,
      totalExcludingTax: Money.fromInt(1000, isoCode: 'AUD'),
      tax: Money.fromInt(0, isoCode: 'AUD'),
      totalIncludingTax: Money.fromInt(1000, isoCode: 'AUD'),
    );
    await DaoReceipt().insert(receipt);

    final tool = Tool.forInsert(
      name: 'Saw',
      supplierId: supplier.id,
      receiptId: receipt.id,
    );
    await DaoTool().insert(tool);

    expect(() => DaoReceipt().delete(receipt.id), throwsA(isA<HMBException>()));
  });
}

Future<Job> _ensureStockJob() async {
  final existing = await DaoJob().getStockJob();
  if (existing != null) {
    return existing;
  }

  final job = await createJobWithCustomer(
    billingType: BillingType.nonBillable,
    hourlyRate: Money.fromInt(0, isoCode: 'AUD'),
    summary: 'Stock',
  );
  final stock = job.copyWith(isStock: true);
  await DaoJob().update(stock);
  return (await DaoJob().getById(stock.id))!;
}
