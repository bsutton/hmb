@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/base_nested/edit_nested_screen.dart';
import 'package:hmb/ui/crud/check_list/edit_task_item_screen.dart';
import 'package:hmb/ui/task_items/material_price_editor.dart';
import 'package:hmb/ui/widgets/blocking_ui.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../../util/settings_test_helper.dart';

void main() {
  setUpAll(prepareSettingsTest);

  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('uses the standard blocking UI while loading system defaults', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            TaskItemEditScreen(
              parent: null,
              billingType: BillingType.timeAndMaterial,
              hourlyRate: MoneyEx.zero,
            ),
            const BlockingOverlay(),
          ],
        ),
      ),
    );

    expect(find.text('Loading...'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    for (var attempt = 0; attempt < 30; attempt++) {
      if (find.text('Description').evaluate().isNotEmpty) {
        break;
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Loading...'), findsNothing);
    expect(find.text('Add Task Item'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    tester
        .widget<HMBDroplist<TaskItemType>>(
          find.byType(HMBDroplist<TaskItemType>),
        )
        .onChanged(TaskItemType.materialsBuy);
    await tester.pumpAndSettle();
    final margin = tester.widget<HMBTextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is HMBTextField &&
            widget.labelText == 'Margin (%) – applied to line total',
      ),
    );
    expect(Percentage.tryParse(margin.controller.text), Percentage.zero);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  for (final forEstimate in [false, true]) {
    testWidgets('cost requirement matches estimate entry: $forEstimate', (
      tester,
    ) async {
      final task = Task.forInsert(
        jobId: 1,
        name: 'Task',
        description: '',
        status: TaskStatus.approved,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TaskItemEditScreen(
            parent: task,
            billingType: BillingType.fixedPrice,
            hourlyRate: MoneyEx.zero,
            forEstimate: forEstimate,
          ),
        ),
      );
      for (var attempt = 0; attempt < 30; attempt++) {
        await tester.pump();
        if (find.text('Description').evaluate().isNotEmpty) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      tester
              .widget<HMBTextField>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is HMBTextField &&
                      widget.labelText == 'Description',
                ),
              )
              .controller
              .text =
          'Unpriced material';
      tester
          .widget<HMBDroplist<TaskItemType>>(
            find.byType(HMBDroplist<TaskItemType>),
          )
          .onChanged(TaskItemType.materialsBuy);
      await tester.pumpAndSettle();
      final pricing = tester
          .widget<MaterialPriceEditor>(find.byType(MaterialPriceEditor))
          .controller;
      expect(pricing.quantity.text, '1');
      expect(pricing.unitCost.text, isEmpty);
      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), !forEstimate);
      if (forEstimate) {
        pricing.unitCost.text = '12.50';
        expect(form.validate(), isTrue);
      }
      final editor = tester.widget<NestedEntityEditScreen<TaskItem, Task>>(
        find.byType(NestedEntityEditScreen<TaskItem, Task>),
      );
      final item = await editor.entityState.forInsert();
      expect(item.estimatedPrice!.quantity, Fixed.one);
      expect(
        item.estimatedPrice!.unitCost,
        forEstimate ? MoneyEx.fromInt(1250) : MoneyEx.zero,
      );
      pricing.unitCost.text = '-1';
      expect(form.validate(), isFalse);
      pricing.unitCost.text = 'invalid';
      expect(form.validate(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
