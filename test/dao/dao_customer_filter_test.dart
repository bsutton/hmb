import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('getByFilter finds customer by linked contact mobile number', () async {
    final customer = await _insertCustomer(
      name: 'Mobile Search Customer',
      mobileNumber: '0412 345 678',
    );
    await _insertCustomer(name: 'Other Customer', mobileNumber: '0499 999 999');

    final results = await DaoCustomer().getByFilter('0412345678');

    expect(results.map((customer) => customer.id), contains(customer.id));
    expect(results.map((customer) => customer.name), isNot(contains('Other')));
  });

  test('getByFilter ignores spaces in mobile search text', () async {
    final customer = await _insertCustomer(
      name: 'Spaced Search Customer',
      mobileNumber: '0412345678',
    );

    final results = await DaoCustomer().getByFilter('0412 345 678');

    expect(results.map((customer) => customer.id), contains(customer.id));
  });
}

Future<Customer> _insertCustomer({
  required String name,
  required String mobileNumber,
}) async {
  final customer = Customer.forInsert(
    name: name,
    description: '',
    disbarred: false,
    customerType: CustomerType.residential,
    hourlyRate: MoneyEx.zero,
    billingContactId: null,
  );
  await DaoCustomer().insert(customer);

  final contact = Contact.forInsert(
    firstName: name,
    surname: 'Contact',
    mobileNumber: mobileNumber,
    landLine: '',
    officeNumber: '',
    emailAddress: '${name.toLowerCase().replaceAll(' ', '.')}@example.com',
  );
  await DaoContact().insert(contact);
  await DaoContactCustomer().insertJoin(contact, customer);
  await DaoContactCustomer().setAsPrimary(contact, customer);

  final savedCustomer = customer.copyWith(billingContactId: contact.id);
  await DaoCustomer().update(savedCustomer);
  return savedCustomer;
}
