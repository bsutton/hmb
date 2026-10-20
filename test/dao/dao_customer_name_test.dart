import 'package:hmb/dao/dao_customer.dart';
import 'package:hmb/entity/customer.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test('ordinary creation and unchanged-name editing succeed', () async {
    final dao = DaoCustomer();
    final customer = _customer('Name validation example');
    expect(await dao.hasDuplicateName(customer.name), isFalse);
    await dao.insert(customer);
    expect(await dao.hasDuplicateName(customer.name), isTrue);
    expect(
      await dao.hasDuplicateName(customer.name, excludingId: customer.id),
      isFalse,
    );
    await dao.update(customer.copyWith(description: 'Updated description'));
    expect(
      (await dao.getById(customer.id))!.description,
      'Updated description',
    );
  });

  test('duplicate insert after preflight receives actionable error', () async {
    final dao = DaoCustomer();
    const name = 'Concurrent customer';
    expect(await dao.hasDuplicateName(name), isFalse);
    // Another save wins after this form's preflight check.
    await dao.insert(_customer(name));
    await expectLater(
      dao.insert(_customer(name)),
      throwsA(
        isA<DuplicateCustomerNameException>().having(
          (error) => error.toString(),
          'message',
          contains(
            'Use the existing customer or enter a different customer name',
          ),
        ),
      ),
    );
  });

  test(
    'duplicate rename is rejected and stored fields remain unchanged',
    () async {
      final dao = DaoCustomer();
      await dao.insert(_customer('Existing customer'));
      final customer = _customer('Other customer');
      await dao.insert(customer);
      expect(
        await dao.hasDuplicateName(
          'Existing customer',
          excludingId: customer.id,
        ),
        isTrue,
      );
      await expectLater(
        dao.update(customer.copyWith(name: 'Existing customer')),
        throwsA(isA<DuplicateCustomerNameException>()),
      );
      expect((await dao.getById(customer.id))!.name, 'Other customer');
    },
  );

  test(
    'case and whitespace retain the database uniqueness semantics',
    () async {
      final dao = DaoCustomer();
      await dao.insert(_customer('Exact customer'));
      for (final name in [
        'exact customer',
        ' Exact customer',
        'Exact customer ',
      ]) {
        expect(await dao.hasDuplicateName(name), isFalse);
        await dao.insert(_customer(name));
      }
    },
  );

  test(
    'unrelated unique constraints are not reported as duplicate names',
    () async {
      await testDb!.execute(
        'CREATE UNIQUE INDEX test_customer_description '
        'ON customer(description) '
        "WHERE description = 'unique description'",
      );
      final dao = DaoCustomer();
      await dao.insert(
        _customer('First').copyWith(description: 'unique description'),
      );
      await expectLater(
        dao.insert(
          _customer('Second').copyWith(description: 'unique description'),
        ),
        throwsA(isA<DatabaseException>()),
      );
      final other = _customer('Third');
      await dao.insert(other);
      await expectLater(
        dao.update(other.copyWith(description: 'unique description')),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test(
    'non-constraint database errors propagate from insert and update',
    () async {
      final dao = DaoCustomer();
      final customer = _customer('Database error');
      await dao.insert(customer);
      await testDb!.execute('DROP TABLE customer');
      await expectLater(
        dao.insert(_customer('New')),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        dao.update(customer),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
}

Customer _customer(String name) => Customer.forInsert(
  name: name,
  description: '',
  disbarred: false,
  customerType: CustomerType.residential,
  hourlyRate: MoneyEx.zero,
  billingContactId: null,
);
