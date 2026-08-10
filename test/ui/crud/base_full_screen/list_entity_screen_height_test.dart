@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/base_full_screen/list_entity_screen.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });

  tearDown(tearDownTestDb);

  testWidgets('variable height cards do not clip their actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final customer = Customer(
      id: 1,
      name: 'Variable height customer',
      description: null,
      disbarred: false,
      customerType: CustomerType.residential,
      hourlyRate: MoneyEx.zero,
      billingContactId: null,
      createdDate: now,
      modifiedDate: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EntityListScreen<Customer>(
          entityNamePlural: 'Customers',
          entityNameSingular: 'Customer',
          dao: DaoCustomer(),
          fetchList: (_) async => [customer],
          listCardTitle: (_) => const Text('Variable card'),
          listCard: (_) => const SizedBox(
            height: 520,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text('Variable height action'),
            ),
          ),
          onEdit: (_) => const SizedBox.shrink(),
          canAdd: false,
          canEdit: (_) => false,
          canDelete: (_) => false,
          cardHeight: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.itemExtent, isNull);
    expect(find.text('Variable height action'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
