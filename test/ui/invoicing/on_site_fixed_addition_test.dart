import 'package:deferred_state/deferred_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/task/edit_task_screen.dart';
import 'package:hmb/ui/invoicing/prepare_invoice_screen.dart';
import 'package:hmb/ui/widgets/fields/hmb_money_field.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/widgets.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../../util/settings_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  setUpAll(prepareSettingsTest);
  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });
  tearDown(tearDownTestDb);

  for (final type in [BillingType.fixedPrice, BillingType.timeAndMaterial]) {
    testWidgets(
      'saved on-site agreement appears in invoice review: ${type.name}',
      (tester) async {
        late Job job;
        await tester.runAsync(() async {
          job = await createJobWithCustomer(
            billingType: type,
            hourlyRate: MoneyEx.zero,
            bookingFee: MoneyEx.zero,
          );
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Stack(
              children: [
                TaskEditScreen(job: job),
                const BlockingOverlay(),
              ],
            ),
          ),
        );
        final state = tester.state<DeferredState<TaskEditScreen>>(
          find.byType(TaskEditScreen),
        );
        await runAsyncAndPump(tester, () => state.initialised);
        await tester.pumpAndSettle();
        final name = tester.widget<HMBTextField>(
          find.byWidgetPredicate(
            (widget) => widget is HMBTextField && widget.labelText == 'Summary',
          ),
        );
        name.controller.text = 'Replace tap washer';
        final typeField = tester.widget<HMBDroplist<BillingTypeOption>>(
          find.byType(HMBDroplist<BillingTypeOption>),
        );
        typeField.onChanged(
          type == BillingType.fixedPrice
              ? BillingTypeOption(null, "Same as job's")
              : BillingTypeOption(BillingType.fixedPrice, 'Fixed Price'),
        );
        await tester.pumpAndSettle();
        final price = tester.widget<HMBMoneyField>(find.byType(HMBMoneyField));
        price.controller.text = '80.00';
        price.onChanged?.call('80.00');
        await tester.pumpAndSettle();
        tester
            .widget<HMBSwitch>(
              find.widgetWithText(HMBSwitch, 'Customer agreed to this price'),
            )
            .onChanged(true);
        await tester.pumpAndSettle();
        expect(find.text('Save and prepare invoice'), findsNothing);
        final save = tester.widget<SaveAndClose>(find.byType(SaveAndClose));
        await runAsyncAndPump(tester, () async {
          await save.onSave(close: false);
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Stack(
              children: [
                PrepareInvoiceScreen(jobId: job.id),
                const BlockingOverlay(),
              ],
            ),
          ),
        );
        await pumpUntilFound(tester, find.byType(PrepareInvoiceScreen));
        final preparation = tester.state<DeferredState<PrepareInvoiceScreen>>(
          find.byType(PrepareInvoiceScreen),
        );
        await runAsyncAndPump(tester, () => preparation.initialised);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Agreed work: Replace tap washer'),
          findsOneWidget,
        );
        expect(find.text('Review charges'), findsOneWidget);
        await tester.runAsync(() async {
          expect(await DaoQuote().getByJobId(job.id), isEmpty);
          expect(await DaoInvoice().getByJobId(job.id), isEmpty);
          final tasks = await DaoTask().getTasksByJob(job.id);
          expect(
            tasks.single.effectiveBillingType(type),
            BillingType.fixedPrice,
          );
          expect(
            tasks.single.billingType,
            type == BillingType.fixedPrice ? isNull : BillingType.fixedPrice,
          );
          expect(
            (await DaoTask().db.query('task_fixed_agreement')).single['amount'],
            8000,
          );
        });
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
