import 'package:deferred_state/deferred_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/task/edit_task_screen.dart';
import 'package:hmb/ui/invoicing/invoice_options_screen.dart';
import 'package:hmb/ui/invoicing/prepare_invoice_screen.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/widgets.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../dao/invoice/milestone_tm_fixture.dart';
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

  testWidgets('correct task, invoice T&M after all milestones, then reopen', (
    tester,
  ) async {
    late MilestoneTmFixture f;
    late Task extra;
    await tester.runAsync(() async {
      f = await MilestoneTmFixture.create();
      await f.invoiceMilestone(0);
      extra = Task.forInsert(
        jobId: f.job.id,
        name: 'Additional work',
        description: '',
        status: TaskStatus.inProgress,
      );
      await DaoTask().insert(extra);
      await f.addLabour(extra);
      await f.invoiceMilestone(1);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            TaskEditScreen(job: f.job, task: extra),
            const BlockingOverlay(),
          ],
        ),
      ),
    );
    final taskEditor = tester.state<DeferredState<TaskEditScreen>>(
      find.byType(TaskEditScreen),
    );
    await runAsyncAndPump(tester, () => taskEditor.initialised);
    await pumpReadOnlyFutureBuilders(tester, find.byType(TaskEditScreen));
    await tester.pumpAndSettle();
    tester
        .widget<HMBDroplist<BillingTypeOption>>(
          find.byType(HMBDroplist<BillingTypeOption>),
        )
        .onChanged(BillingTypeOption(BillingType.timeAndMaterial, 'T&M'));
    await tester.pump();
    await pumpReadOnlyFutureBuilders(tester, find.byType(TaskEditScreen));
    await tester.pumpAndSettle();
    final save = tester.widget<SaveAndClose>(find.byType(SaveAndClose));
    await runAsyncAndPump(tester, () => save.onSave(close: false));
    await pumpReadOnlyFutureBuilders(tester, find.byType(TaskEditScreen));
    await tester.runAsync(() async {
      expect(
        (await DaoTask().getById(extra.id))!.billingType,
        BillingType.timeAndMaterial,
      );
      expect((await DaoTimeEntry().getByTask(extra.id)).single.billed, isFalse);
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    Invoice? created;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                created = await Navigator.of(context).push<Invoice>(
                  MaterialPageRoute(
                    builder: (_) => PrepareInvoiceScreen(jobId: f.job.id),
                  ),
                );
              },
              child: const Text('Review job charges'),
            ),
          ),
        ),
      ),
    );

    Future<void> openReview() async {
      await tester.tap(find.text('Review job charges'));
      await pumpUntilFound(tester, find.byType(PrepareInvoiceScreen));
      final state = tester.state<DeferredState<PrepareInvoiceScreen>>(
        find.byType(PrepareInvoiceScreen),
      );
      await runAsyncAndPump(tester, () => state.initialised);
      await tester.pumpAndSettle();
    }

    await openReview();
    expect(find.text('Total: ${MoneyEx.dollars(176)}'), findsOneWidget);
    expect(find.textContaining('Labour:'), findsOneWidget);
    final continueButton = find.widgetWithText(
      HMBButtonPrimary,
      'Continue to invoice',
    );
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await pumpUntilFound(tester, find.byType(InvoiceOptionsScreen));
    await tester.pumpAndSettle();
    final createButton = find.widgetWithText(
      HMBButtonPrimary,
      'Create draft invoice',
    );
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await pumpUntilCondition(tester, () => created != null, 'created invoice');
    await tester.pumpAndSettle();
    expect(created!.totalAmount, MoneyEx.dollars(176));
    await tester.runAsync(() async {
      final groups = await DaoInvoiceLineGroup().getByInvoiceId(created!.id);
      expect(groups.single.name, extra.name);
      expect(await DaoInvoice().getByJobId(f.job.id), hasLength(3));
    });
    await openReview();
    expect(find.text('No charges are ready to invoice.'), findsOneWidget);
    expect(find.text('Total: ${MoneyEx.zero}'), findsOneWidget);
    expect(tester.widget<HMBButtonPrimary>(continueButton).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
