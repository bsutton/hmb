@Tags(['flutter'])
library;

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/base_nested/edit_nested_screen.dart';
import 'package:hmb/ui/crud/task/edit_task_screen.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  testWidgets('Same as job remains inherited when a task is saved', (
    tester,
  ) async {
    late Job job;
    await runAsyncAndPump(tester, () async {
      job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.dollars(88),
      );
    });

    await tester.pumpWidget(MaterialApp(home: TaskEditScreen(job: job)));
    final state = tester.state<DeferredState<TaskEditScreen>>(
      find.byType(TaskEditScreen),
    );
    await runAsyncAndPump(tester, () => state.initialised);
    tester
            .widget<HMBTextField>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is HMBTextField && widget.labelText == 'Summary',
              ),
            )
            .controller
            .text =
        'Inherited task';
    final editor = tester.widget<NestedEntityEditScreen<Task, Job>>(
      find.byType(NestedEntityEditScreen<Task, Job>),
    );
    final task = await editor.entityState.forInsert();
    expect(task.billingType, isNull);
    expect(
      task.effectiveBillingType(BillingType.fixedPrice),
      BillingType.fixedPrice,
    );
  });
}
