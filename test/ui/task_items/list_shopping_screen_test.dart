@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/ui/task_items/list_packing_screen.dart';
import 'package:hmb/ui/task_items/list_shopping_screen.dart';
import 'package:hmb/ui/task_items/purchased_item_card.dart';
import 'package:hmb/ui/widgets/layout/surface.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist_multi.dart';
import 'package:hmb/ui/widgets/select/hmb_select_job_multi.dart'
    hide CustomerAndJob;
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitForFinder(
    WidgetTester tester,
    Finder finder, {
    int attempts = 30,
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    throw TestFailure('Timed out waiting for $finder');
  }

  Future<void> waitForText(
    WidgetTester tester,
    String text, {
    int attempts = 30,
  }) => waitForFinder(tester, find.text(text), attempts: attempts);

  Future<void> waitForDatabaseWork(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('shows delete action for shopping items', (tester) async {
    await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
        summary: 'Shopping Delete Job',
      );
      job.status = JobStatus.scheduled;
      await DaoJob().update(job);

      final task = Task.forInsert(
        jobId: job.id,
        name: 'Shopping Task',
        description: 'Task with shopping item',
        status: TaskStatus.approved,
      );
      final taskId = await DaoTask().insert(task);

      await DaoTaskItem().insert(
        TaskItem.forInsert(
          taskId: taskId,
          description: 'Buy material item',
          purpose: '',
          itemType: TaskItemType.materialsBuy,
          margin: Percentage.zero,
          measurementType: MeasurementType.length,
          dimension1: Fixed.fromNum(1, decimalDigits: 3),
          dimension2: Fixed.fromNum(1, decimalDigits: 3),
          dimension3: Fixed.fromNum(1, decimalDigits: 3),
          units: Units.m,
          url: '',
          labourEntryMode: LabourEntryMode.hours,
          chargeMode: ChargeMode.calculated,
          estimatedMaterialUnitCost: Money.fromInt(1000, isoCode: 'AUD'),
          estimatedMaterialQuantity: Fixed.fromNum(1, decimalDigits: 3),
        ),
      );
    });

    await tester.pumpWidget(const MaterialApp(home: ShoppingScreen()));
    await tester.pumpAndSettle();
    await waitForText(tester, 'Buy material item');

    expect(find.text('Buy material item'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsWidgets);
    expect(find.byIcon(Icons.delete), findsWidgets);
  });

  testWidgets('long shopping item text keeps action icons visible', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
        summary:
            'Very long shopping job name that should ellipsize instead of '
            'wrapping over the action buttons on the card',
      );
      job.status = JobStatus.scheduled;
      await DaoJob().update(job);

      final task = Task.forInsert(
        jobId: job.id,
        name:
            'Very long shopping task name that must stay on one line in the '
            'shopping card body',
        description: 'Task with long shopping item',
        status: TaskStatus.approved,
      );
      final taskId = await DaoTask().insert(task);

      await DaoTaskItem().insert(
        TaskItem.forInsert(
          taskId: taskId,
          description:
              'Buy an unusually long material description that should be '
              'ellipsized to a single card title line',
          purpose:
              'A long note that should not push the complete, delete, and edit '
              'icons off the bottom of the card',
          itemType: TaskItemType.materialsBuy,
          margin: Percentage.zero,
          measurementType: MeasurementType.length,
          dimension1: Fixed.fromNum(1, decimalDigits: 3),
          dimension2: Fixed.fromNum(1, decimalDigits: 3),
          dimension3: Fixed.fromNum(1, decimalDigits: 3),
          units: Units.m,
          url: '',
          labourEntryMode: LabourEntryMode.hours,
          chargeMode: ChargeMode.calculated,
          estimatedMaterialUnitCost: Money.fromInt(1000, isoCode: 'AUD'),
          estimatedMaterialQuantity: Fixed.fromNum(1, decimalDigits: 3),
        ),
      );
    });

    await tester.pumpWidget(const MaterialApp(home: ShoppingScreen()));
    await tester.pumpAndSettle();
    await waitForText(
      tester,
      'Buy an unusually long material description that should be ellipsized '
      'to a single card title line',
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.check), findsWidgets);
    expect(find.byIcon(Icons.delete), findsWidgets);
    expect(find.byIcon(Icons.edit), findsWidgets);
  });

  testWidgets('purchased card fits supplier and purchase details', (
    tester,
  ) async {
    late TaskItemContext itemContext;
    late CustomerAndJob details;
    await tester.runAsync(() async {
      final job =
          await createJobWithCustomer(
              billingType: BillingType.fixedPrice,
              hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
              bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
              summary: 'Purchased card layout job',
            )
            ..status = JobStatus.inProgress;
      await DaoJob().update(job);

      final supplier = Supplier.forInsert(
        name: 'Purchased card supplier',
        businessNumber: '',
        description: '',
        bsb: '',
        accountNumber: '',
        service: '',
      );
      await DaoSupplier().insert(supplier);

      final task = Task.forInsert(
        jobId: job.id,
        name: 'Purchased card task',
        description: '',
        status: TaskStatus.inProgress,
      );
      await DaoTask().insert(task);

      final item = TaskItem.forInsert(
        taskId: task.id,
        description: 'Purchased card item',
        purpose: 'Purchase note',
        itemType: TaskItemType.materialsBuy,
        margin: Percentage.zero,
        measurementType: MeasurementType.length,
        dimension1: Fixed.one,
        dimension2: Fixed.one,
        dimension3: Fixed.one,
        units: Units.m,
        url: '',
        labourEntryMode: LabourEntryMode.hours,
        chargeMode: ChargeMode.calculated,
        estimatedMaterialUnitCost: Money.fromInt(2800, isoCode: 'AUD'),
        estimatedMaterialQuantity: Fixed.one,
        actualMaterialUnitCost: Money.fromInt(2800, isoCode: 'AUD'),
        actualMaterialQuantity: Fixed.one,
        supplierId: supplier.id,
        completed: true,
      );
      await DaoTaskItem().insert(item);

      itemContext = TaskItemContext(
        task: task,
        taskItem: item,
        billingType: BillingType.fixedPrice,
        wasReturned: false,
      );
      details = await CustomerAndJob.fetch(itemContext);
    });

    await tester.binding.setSurfaceSize(const Size(768, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              PurchasedItemCard(
                itemContext: itemContext,
                details: details,
                onReload: () async {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Purchased card item'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Supplier: Purchased card supplier'), findsOneWidget);
    expect(find.text('Note: Purchase note'), findsOneWidget);
    final cardFinder = find.byKey(
      ValueKey('shopping-item-card-${itemContext.taskItem.id}'),
    );
    final card = tester.widget<Surface>(cardFinder);
    expect(card.elevation, SurfaceElevation.e6);
    expect(card.margin, const EdgeInsets.only(bottom: 8));
    expect(tester.getSize(cardFinder).height, lessThan(340));
  });

  testWidgets('multi-job selector can include inactive jobs on request', (
    tester,
  ) async {
    late Job activeJob;
    late Job inactiveJob;
    await tester.runAsync(() async {
      activeJob =
          await createJobWithCustomer(
              billingType: BillingType.fixedPrice,
              hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
              bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
              summary: 'Active history selector job',
            )
            ..status = JobStatus.inProgress;
      await DaoJob().update(activeJob);

      inactiveJob =
          await createJobWithCustomer(
              billingType: BillingType.fixedPrice,
              hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
              bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
              summary: 'Inactive history selector job',
            )
            ..status = JobStatus.completed;
      await DaoJob().update(inactiveJob);
    });

    var showInactiveJobs = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBSelectJobMulti(
            initialJobs: const [],
            onChanged: (_) {},
            allowInactiveJobs: true,
            showInactiveJobs: showInactiveJobs,
            onShowInactiveJobsChanged: (value) {
              showInactiveJobs = value;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select Jobs'));
    await tester.pump();
    await waitForFinder(tester, find.textContaining(activeJob.summary));

    expect(find.textContaining(activeJob.summary), findsOneWidget);
    expect(find.textContaining(inactiveJob.summary), findsNothing);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Show inactive jobs'));
    await tester.pump();
    await waitForFinder(tester, find.textContaining(inactiveJob.summary));

    expect(showInactiveJobs, isTrue);
    expect(find.textContaining(inactiveJob.summary), findsOneWidget);
  });

  testWidgets('multi-select search keeps results visible while loading', (
    tester,
  ) async {
    final searchResults = Completer<List<String>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBDroplistMultiSelect<String>(
            initialItems: () async => [],
            items: (filter) async {
              if (filter == null || filter.isEmpty) {
                return ['Alpha', 'Beta'];
              }
              return searchResults.future;
            },
            format: (item) => item,
            onChanged: (_) {},
            title: 'Items',
            required: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select Items'));
    await tester.pumpAndSettle();

    final initialSize = tester.getSize(find.byType(Dialog));
    expect(find.text('Alpha'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(Dialog)), initialSize);

    searchResults.complete(['Alpha']);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('purchased and returns share the history range', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShoppingScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('To Purchase').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Purchased').last);
    await tester.pumpAndSettle();
    await waitForDatabaseWork(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Purchased in'), findsOneWidget);
    expect(find.text('Last 30 Days'), findsOneWidget);

    await tester.tap(find.text('Last 30 Days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 90 Days'));
    await tester.pumpAndSettle();
    await waitForDatabaseWork(tester);
    Navigator.of(tester.element(find.text('Purchased in'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Purchased').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Returns').last);
    await tester.pumpAndSettle();
    await waitForDatabaseWork(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Returned in'), findsOneWidget);
    expect(find.text('Last 90 Days'), findsOneWidget);
    Navigator.of(tester.element(find.text('Returned in'))).pop();
    await waitForDatabaseWork(tester);
  });
}
