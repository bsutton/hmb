@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_customer.dart';
import 'package:hmb/entity/customer.dart';
import 'package:hmb/ui/crud/base_nested/list_nested_screen.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('add child saves a new parent before opening editor', (
    tester,
  ) async {
    final parent = Parent<Customer>(null);
    var saveCount = 0;
    var openedEditor = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParentSaveScope(
            ensureSaved: () async {
              saveCount++;
              return _customer()..id = 42;
            },
            child: NestedEntityListScreen<Customer, Customer>(
              dao: DaoCustomer(),
              entityNamePlural: 'Contacts',
              entityNameSingular: 'contact',
              parentTitle: 'Customer',
              parent: parent,
              fetchList: () async => const [],
              title: (entity) => Text(entity.name),
              details: (entity, detail) => Text(entity.name),
              onDelete: (_) async {},
              onEdit: (_) {
                openedEditor = true;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(saveCount, 1);
    expect(parent.parent?.id, 42);
    expect(openedEditor, isTrue);
  });

  testWidgets('add child stops when parent save validation fails', (
    tester,
  ) async {
    final parent = Parent<Customer>(null);
    var openedEditor = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParentSaveScope(
            ensureSaved: () async => null,
            child: NestedEntityListScreen<Customer, Customer>(
              dao: DaoCustomer(),
              entityNamePlural: 'Contacts',
              entityNameSingular: 'contact',
              parentTitle: 'Customer',
              parent: parent,
              fetchList: () async => const [],
              title: (entity) => Text(entity.name),
              details: (entity, detail) => Text(entity.name),
              onDelete: (_) async {},
              onEdit: (_) {
                openedEditor = true;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(parent.parent, isNull);
    expect(openedEditor, isFalse);
  });
}

Customer _customer() => Customer.forInsert(
  name: 'Customer',
  description: '',
  disbarred: false,
  customerType: CustomerType.residential,
  hourlyRate: MoneyEx.zero,
  billingContactId: null,
);
