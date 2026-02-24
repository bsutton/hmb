import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/exceptions.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('cannot delete customer with related jobs', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Delete guard customer job',
    );

    expect(
      () => DaoCustomer().delete(job.customerId!),
      throwsA(isA<HMBException>()),
    );

    final reloaded = await DaoCustomer().getById(job.customerId);
    expect(reloaded, isNotNull);
  });

  test('deletes customer with no related jobs and removes join rows', () async {
    final customer = await _insertStandaloneCustomer();

    final contact = Contact.forInsert(
      firstName: 'Delete',
      surname: 'Allowed',
      mobileNumber: '0400000000',
      landLine: '',
      officeNumber: '',
      emailAddress: 'delete-allowed@example.com',
    );
    await DaoContact().insert(contact);
    await DaoContactCustomer().insertJoin(contact, customer);

    final site = Site.forInsert(
      addressLine1: '1 Main St',
      addressLine2: '',
      suburb: 'Town',
      state: 'TS',
      postcode: '1234',
      accessDetails: '',
    );
    await DaoSite().insert(site);
    await DaoSiteCustomer().insertJoin(site, customer);

    await DaoCustomer().delete(customer.id);

    expect(await DaoCustomer().getById(customer.id), isNull);
    expect(
      await DaoContactCustomer().count(
        where: 'customer_id = ?',
        whereArgs: [customer.id],
      ),
      0,
    );
    expect(
      await DaoSiteCustomer().count(
        where: 'customer_id = ?',
        whereArgs: [customer.id],
      ),
      0,
    );
  });
}

Future<Customer> _insertStandaloneCustomer() async {
  final unique = DateTime.now().microsecondsSinceEpoch;
  final customer = Customer.forInsert(
    name: 'Standalone Customer $unique',
    description: '',
    disbarred: false,
    customerType: CustomerType.residential,
    hourlyRate: MoneyEx.zero,
    billingContactId: null,
  );
  await DaoCustomer().insert(customer);
  return customer;
}
