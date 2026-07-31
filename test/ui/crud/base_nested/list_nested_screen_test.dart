@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_customer.dart';
import 'package:hmb/entity/customer.dart';
import 'package:hmb/ui/crud/base_nested/list_nested_screen.dart';
import 'package:hmb/ui/widgets/icons/hmb_add_button.dart';
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

  testWidgets('filter and add controls fit on a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final parent = _customer()..id = 42;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NestedEntityListScreen<Customer, Customer>(
            dao: DaoCustomer(),
            entityNamePlural: 'Contacts',
            entityNameSingular: 'contact',
            parentTitle: 'Customer',
            parent: Parent(parent),
            fetchList: () async => [parent],
            filterBar: (_) => const SizedBox(
              width: 320,
              child: TextField(
                decoration: InputDecoration(labelText: 'Search Task Items'),
              ),
            ),
            title: (entity) => Text(entity.name),
            details: (entity, detail) => Text(entity.name),
            onDelete: (_) async {},
            onEdit: (_) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Search Task Items'), findsOneWidget);
    expect(find.text('Show details'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(HMBButtonAdd)).dy,
      tester.getTopLeft(find.byType(TextField)).dy,
    );
  });

  testWidgets('detail toggle appears only for lists that support it', (
    tester,
  ) async {
    final parent = _customer()..id = 42;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NestedEntityListScreen<Customer, Customer>(
            dao: DaoCustomer(),
            entityNamePlural: 'Contacts',
            entityNameSingular: 'contact',
            parentTitle: 'Customer',
            parent: Parent(parent),
            fetchList: () async => [parent],
            supportsDetailToggle: true,
            title: (entity) => Text(entity.name),
            details: (entity, detail) => Text(detail.name),
            onDelete: (_) async {},
            onEdit: (_) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show details'), findsOneWidget);
    expect(find.text(CardDetail.summary.name), findsOneWidget);

    await tester.tap(find.byIcon(Icons.toggle_off));
    await tester.pump();

    expect(find.text(CardDetail.full.name), findsOneWidget);
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
