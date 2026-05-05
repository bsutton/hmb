import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
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

  test('filters receipts by supplier name search', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
    );
    final acme = await _insertSupplier('Acme Hardware');
    final beta = await _insertSupplier('Beta Plumbing');

    await _insertReceipt(
      jobId: job.id,
      supplierId: acme.id,
      receiptDate: DateTime(2026, 1, 1, 10),
    );
    await _insertReceipt(
      jobId: job.id,
      supplierId: beta.id,
      receiptDate: DateTime(2026, 1, 2, 10),
    );

    final receipts = await DaoReceipt().getByFilter(supplierFilter: 'acme');

    expect(receipts, hasLength(1));
    expect(receipts.single.supplierId, acme.id);
  });

  test('filters receipts by supplier and receipt date range', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
    );
    final acme = await _insertSupplier('Acme Hardware');
    final beta = await _insertSupplier('Beta Plumbing');

    await _insertReceipt(
      jobId: job.id,
      supplierId: acme.id,
      receiptDate: DateTime(2026, 1, 1, 10),
    );
    final matching = await _insertReceipt(
      jobId: job.id,
      supplierId: acme.id,
      receiptDate: DateTime(2026, 1, 2, 14),
    );
    await _insertReceipt(
      jobId: job.id,
      supplierId: beta.id,
      receiptDate: DateTime(2026, 1, 2, 16),
    );
    await _insertReceipt(
      jobId: job.id,
      supplierId: acme.id,
      receiptDate: DateTime(2026, 1, 3, 10),
    );

    final receipts = await DaoReceipt().getByFilter(
      supplierId: acme.id,
      dateFrom: DateTime(2026, 1, 2),
      dateTo: DateTime(2026, 1, 2, 23, 59, 59, 999),
    );

    expect(receipts.map((receipt) => receipt.id), [matching.id]);
  });
}

Future<Supplier> _insertSupplier(String name) async {
  final supplier = Supplier.forInsert(
    name: name,
    businessNumber: '',
    description: 'Test supplier',
    bsb: '',
    accountNumber: '',
    service: '',
  );
  await DaoSupplier().insert(supplier);
  return supplier;
}

Future<Receipt> _insertReceipt({
  required int jobId,
  required int supplierId,
  required DateTime receiptDate,
}) async {
  final receipt = Receipt.forInsert(
    receiptDate: receiptDate,
    jobId: jobId,
    supplierId: supplierId,
    totalExcludingTax: Money.fromInt(10000, isoCode: 'AUD'),
    tax: Money.fromInt(1000, isoCode: 'AUD'),
    totalIncludingTax: Money.fromInt(11000, isoCode: 'AUD'),
  );
  await DaoReceipt().insert(receipt);
  return receipt;
}
