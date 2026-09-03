import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/exceptions.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test('referenced tool metadata cannot be deleted', () async {
    final supplier = Supplier.forInsert(
      name: 'Tool Supplier',
      businessNumber: null,
      description: null,
      bsb: null,
      accountNumber: null,
      service: null,
    );
    final manufacturer = Manufacturer.forInsert(name: 'Tool Maker');
    final category = Category.forInsert(name: 'Power tools');
    await DaoSupplier().insert(supplier);
    await DaoManufacturer().insert(manufacturer);
    await DaoCategory().insert(category);
    final tool = Tool.forInsert(
      name: 'Drill',
      supplierId: supplier.id,
      manufacturerId: manufacturer.id,
      categoryId: category.id,
    );
    await DaoTool().insert(tool);

    for (final deletion in <Future<int> Function()>[
      () => DaoSupplier().delete(supplier.id),
      () => DaoManufacturer().delete(manufacturer.id),
      () => DaoCategory().delete(category.id),
    ]) {
      await expectLater(deletion, throwsA(isA<HMBException>()));
    }

    await DaoTool().delete(tool.id);
    expect(await DaoSupplier().delete(supplier.id), 1);
    expect(await DaoManufacturer().delete(manufacturer.id), 1);
    expect(await DaoCategory().delete(category.id), 1);
  });

  test('contact linked to a customer cannot be deleted', () async {
    final customer = Customer.forInsert(
      name: 'Contact Customer',
      description: '',
      disbarred: false,
      customerType: CustomerType.residential,
      hourlyRate: MoneyEx.zero,
      billingContactId: null,
    );
    await DaoCustomer().insert(customer);
    final contact = Contact.forInsert(
      firstName: 'Casey',
      surname: 'Contact',
      mobileNumber: '',
      landLine: '',
      officeNumber: '',
      emailAddress: '',
    );
    await DatabaseHelper.instance.database.transaction(
      (transaction) =>
          DaoContact().insertForCustomer(contact, customer, transaction),
    );

    await expectLater(
      () => DaoContact().delete(contact.id),
      throwsA(isA<HMBException>()),
    );
  });
}
