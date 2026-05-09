import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:money2/money2.dart';
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

  test('supplier filter orders recently used suppliers first', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
    );
    final alpha = await _insertSupplier('Alpha Hardware');
    final beta = await _insertSupplier('Beta Plumbing');
    final zeta = await _insertSupplier('Zeta Electrical');

    await _insertReceipt(
      jobId: job.id,
      supplierId: alpha.id,
      receiptDate: DateTime(2026, 1, 3),
    );
    await _insertReceipt(
      jobId: job.id,
      supplierId: zeta.id,
      receiptDate: DateTime(2026, 1, 4),
    );

    final suppliers = await DaoSupplier().getByFilter(null);
    final ids = suppliers.map((supplier) => supplier.id).toList();

    expect(ids.indexOf(zeta.id), lessThan(ids.indexOf(alpha.id)));
    expect(ids.indexOf(alpha.id), lessThan(ids.indexOf(beta.id)));
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

Future<void> _insertReceipt({
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
}
