@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/database/factory/cli_database_factory.dart';
import 'package:hmb/database/versions/post_upgrade/post_upgrade_134.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/ui/task_items/list_packing_screen.dart';
import 'package:hmb/ui/task_items/material_price_editor.dart';
import 'package:hmb/ui/widgets/icons/hmb_add_button.dart';
import 'package:hmb/ui/widgets/select/select.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';
import 'package:toastification/toastification.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../../util/settings_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(prepareSettingsTest);

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
    await resetSettingsForTest();
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
          await DaoTask().insert(
            Task.forInsert(
              jobId: job.id,
              name: 'Packing task',
              description: '',
              status: TaskStatus.approved,
            ),
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
        await tester.pumpAndSettle();
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

  for (final width in [800.0, 1200.0]) {
    testWidgets('packing delete and DB reopen at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late int itemId;
      late int jobId;
      await tester.runAsync(() async {
        final job = await createJobWithCustomer(
          billingType: BillingType.fixedPrice,
          hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
          bookingFee: Money.fromInt(10000, isoCode: 'AUD'),
          summary: 'Packing Move Job',
        );
        await setJobStatusForTest(job, JobStatus.scheduled);
        jobId = job.id;

        final task = Task.forInsert(
          jobId: job.id,
          name: 'Packing Task',
          description: 'Task with stock item',
          status: TaskStatus.approved,
        );
        final taskId = await DaoTask().insert(task);

        itemId = await DaoTaskItem().insert(
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

      await tester.pumpWidget(
        const ToastificationWrapper(child: MaterialApp(home: PackingScreen())),
      );
      await pumpDeferredStates(tester);
      await tester.pumpAndSettle();
      await waitForText(tester, 'Stock material item');

      expect(find.text('Stock material item'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart), findsWidgets);
      final oldBuilder =
          (width < 900
                  ? tester
                        .widget<ListView>(find.byType(ListView).last)
                        .childrenDelegate
                  : tester
                        .widget<GridView>(find.byType(GridView))
                        .childrenDelegate)
              as SliverChildBuilderDelegate;
      final screenContext = tester.element(find.byType(PackingScreen));

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await runAsyncAndPump(tester, () async {
        expect(await DaoTaskItem().getById(itemId), isNotNull);
        expect(await DaoJob().getById(jobId), isNotNull);
      });

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await pumpUntilCondition(
        tester,
        () => find.text('Stock material item').evaluate().isEmpty,
        'packing item deletion',
      );
      await runAsyncAndPump(tester, () async {
        expect(
          await DaoTaskItem()
              .getById(itemId)
              .timeout(const Duration(seconds: 3)),
          isNull,
        );
        expect(
          await DaoJob().getById(jobId).timeout(const Duration(seconds: 3)),
          isNotNull,
        );
      });
      // A lazy builder retained from the previous frame must still be safe
      // after a refresh has published an empty list.
      expect(() => oldBuilder.builder(screenContext, 0), returnsNormally);
      toastification.dismissAll();
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const MaterialApp(home: PackingScreen()));
      await pumpDeferredStates(tester);
      await tester.pumpAndSettle();
      expect(find.text('Stock material item'), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        // Reopen the persisted disposable DB and run the startup data step.
        // This is separate from reopening the screen above.
        await DatabaseHelper().closeDb();
        await DatabaseHelper().withOpenDatabase(
          CliDatabaseFactory(),
          testDbPath,
          () async {
            await postv134Upgrade(
              DatabaseHelper().database,
            ).timeout(const Duration(seconds: 3));
            expect(await DaoTaskItem().getById(itemId), isNull);
            expect(await DaoJob().getById(jobId), isNotNull);
          },
        );
      });
    });
  }
}
