@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/ui/task_items/list_packing_screen.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';
import 'package:hmb/ui/task_items/material_price_editor.dart';
import 'package:hmb/ui/widgets/select/select.g.dart';
import 'package:hmb/ui/widgets/icons/hmb_add_button.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitForText(
    WidgetTester tester,
    String text, {
    int attempts = 30,
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (find.text(text).evaluate().isNotEmpty) {
        return;
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    throw TestFailure('Timed out waiting for text: $text');
  }

  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  for (final changeDefaults in [false, true]) {
    testWidgets(
      'main packing Add saves defaults or edited values: $changeDefaults',
      (tester) async {
        late Job job;
        await tester.runAsync(() async {
          job = await createJobWithCustomer(
            billingType: BillingType.fixedPrice,
            hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
            bookingFee: Money.fromInt(0, isoCode: 'AUD'),
            summary: 'Packing defaults',
          );
        });
        await tester.pumpWidget(const MaterialApp(home: PackingScreen()));
        await pumpDeferredStates(tester);
        await tester.tap(find.byType(HMBButtonAdd));
        await tester.pumpAndSettle();
        final editor = tester.widget<MaterialPriceEditor>(
          find.byType(MaterialPriceEditor),
        );
        expect(editor.controller.quantity.text, '1');
        expect(editor.controller.unitCost.text, r'$0.00');
        tester.widget<HMBSelectJob>(find.byType(HMBSelectJob)).onSelected!(job);
        for (var i = 0; i < 15; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        tester
            .widget<HMBDroplist<TaskItemType>>(
              find.byType(HMBDroplist<TaskItemType>),
            )
            .onChanged(TaskItemType.materialsStock);
        await tester.pump();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Description'),
          'Default packing item',
        );
        if (changeDefaults) {
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Quantity'),
            '3',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Cost per item'),
            '4.50',
          );
        }
        await tester.ensureVisible(find.text('Add'));
        await tester.tap(find.text('Add'));
        for (var i = 0; i < 15; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(find.text('Add Packing Item'), findsNothing);
        await tester.runAsync(() async {
          final task = await DaoTask().defaultTaskForMaterials(job.id);
          final item = (await DaoTaskItem().getByTask(task!.id)).single;
          expect(
            item.estimatedPrice!.quantity,
            Fixed.fromNum(changeDefaults ? 3 : 1),
          );
          expect(
            item.estimatedPrice!.unitCost,
            Money.fromInt(changeDefaults ? 450 : 0, isoCode: 'AUD'),
          );
        });
      },
    );
  }

  testWidgets('shows move-to-shopping action for packing items', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
        bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
        summary: 'Packing Move Job',
      );
      await setJobStatusForTest(job, JobStatus.scheduled);

      final task = Task.forInsert(
        jobId: job.id,
        name: 'Packing Task',
        description: 'Task with stock item',
        status: TaskStatus.approved,
      );
      final taskId = await DaoTask().insert(task);

      await DaoTaskItem().insert(
        TaskItem.forInsert(
          taskId: taskId,
          description: 'Stock material item',
          purpose: '',
          itemType: TaskItemType.materialsStock,
          margin: Percentage.zero,
          measurementType: MeasurementType.length,
          dimension1: Fixed.fromNum(1, decimalDigits: 3),
          dimension2: Fixed.fromNum(1, decimalDigits: 3),
          dimension3: Fixed.fromNum(1, decimalDigits: 3),
          units: Units.m,
          url: '',
          labourEntryMode: LabourEntryMode.hours,
          chargeMode: ChargeMode.calculated,
          estimatedPrice: MaterialPrice.items(
            quantity: Fixed.fromNum(1, decimalDigits: 3),
            unitCost: Money.fromInt(1000, isoCode: 'AUD'),
          ),
        ),
      );
    });

    await tester.pumpWidget(const MaterialApp(home: PackingScreen()));
    await pumpDeferredStates(tester);
    await tester.pumpAndSettle();
    await waitForText(tester, 'Stock material item');

    expect(find.text('Stock material item'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart), findsWidgets);
  });
}
