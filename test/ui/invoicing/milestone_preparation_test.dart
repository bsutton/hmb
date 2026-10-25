import 'package:deferred_state/deferred_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/milestone/edit_milestone_payment.dart';
import 'package:hmb/ui/crud/milestone/milestone_tile.dart';
import 'package:hmb/ui/invoicing/invoice_options_screen.dart';
import 'package:hmb/ui/invoicing/prepare_invoice_screen.dart';
import 'package:hmb/ui/widgets/fields/hmb_money_field.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/widgets.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:june/june.dart';
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

  Future<Job> seed() async {
    final job = await createJobWithCustomer(
      billingType: BillingType.fixedPrice,
      hourlyRate: MoneyEx.dollars(100),
      bookingFee: MoneyEx.zero,
    );
    await DaoQuote().insert(
      Quote.forInsert(
        jobId: job.id,
        summary: 'Kitchen installation',
        description: '',
        totalAmount: MoneyEx.dollars(1000),
        state: QuoteState.approved,
      ),
    );
    final task = Task.forInsert(
      jobId: job.id,
      name: 'Extra repairs',
      description: '',
      billingType: BillingType.timeAndMaterial,
      status: TaskStatus.completed,
    );
    await DaoTask().insert(task);
    await DaoTimeEntry().insert(
      TimeEntry.forInsert(
        taskId: task.id,
        startTime: DateTime(2026, 10, 24, 9),
        endTime: DateTime(2026, 10, 24, 10),
        note: 'Extra repairs',
      ),
    );
    return job;
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Job job;
    await tester.runAsync(() async => job = await seed());
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: PrepareInvoiceScreen(jobId: job.id),
      ),
    );
    final state = tester.state<DeferredState<PrepareInvoiceScreen>>(
      find.byType(PrepareInvoiceScreen),
    );
    await runAsyncAndPump(tester, () => state.initialised);
    await tester.pumpAndSettle();
  }

  Future<void> split(WidgetTester tester) async {
    tester
        .widget<HMBButtonSecondary>(
          find.widgetWithText(HMBButtonSecondary, 'Split into milestones'),
        )
        .onPressed!();
    await pumpUntilFound(tester, find.byType(EditMilestonesScreen));
    final state = tester.state<DeferredState<EditMilestonesScreen>>(
      find.byType(EditMilestonesScreen),
    );
    await runAsyncAndPump(tester, () => state.initialised);
    await tester.pumpAndSettle();
  }

  Future<void> waitForRefresh(WidgetTester tester) async {
    await tester.pump();
    await pumpUntilCondition(
      tester,
      () =>
          !June.getState(BlockingOverlayState.new).blocked &&
          find.byType(EditMilestonesScreen).evaluate().isEmpty,
      'schedule refresh',
    );
    await tester.pumpAndSettle();
  }

  testWidgets('fixed quote prompts while actual work remains selected', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('How will this fixed price be billed?'), findsOneWidget);
    expect(find.text(r'Total: $100.00'), findsOneWidget);
    expect(
      tester
          .widget<HMBButtonPrimary>(
            find.widgetWithText(HMBButtonPrimary, 'Continue to invoice'),
          )
          .onPressed,
      isNotNull,
    );
    tester
        .widget<HMBButtonSecondary>(
          find.widgetWithText(HMBButtonSecondary, 'Bill in full'),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text(r'Total: $1,100.00'), findsOneWidget);
  });

  testWidgets('cancelled schedule leaves fixed price unselected', (
    tester,
  ) async {
    await mount(tester);
    await split(tester);
    tester
        .widget<HMBButtonSecondary>(
          find.widgetWithText(HMBButtonSecondary, 'Done'),
        )
        .onPressed!();
    await waitForRefresh(tester);
    expect(find.byType(EditMilestonesScreen), findsNothing);
    expect(find.text('Bill in full'), findsOneWidget);
    expect(find.text(r'Total: $100.00'), findsOneWidget);
  });

  testWidgets('billing edits persist and invoice options are a separate step', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Payment due'), findsNothing);
    expect(find.text('Group labour by task'), findsNothing);
    expect(find.text('Refresh charges'), findsNothing);
    final fee = tester.widget<HMBMoneyField>(find.byType(HMBMoneyField));
    fee.controller.text = '25.00';
    tester
        .widget<HMBDroplist<BillingType>>(find.byType(HMBDroplist<BillingType>))
        .onChanged(BillingType.timeAndMaterial);
    tester
        .widget<HMBButtonSecondary>(
          find.widgetWithText(HMBButtonSecondary, 'Save changes'),
        )
        .onPressed!();
    await pumpUntilFound(tester, find.text(r'Total: $125.00'));
    await tester.pumpAndSettle();
    final screen = tester.widget<PrepareInvoiceScreen>(
      find.byType(PrepareInvoiceScreen),
    );
    await tester.runAsync(() async {
      final job = (await DaoJob().getById(screen.jobId))!;
      expect(job.bookingFee, MoneyEx.dollars(25));
      expect(job.billingType, BillingType.timeAndMaterial);
    });
    expect(find.text(r'Total: $125.00'), findsOneWidget);
    // Continue saves and recalculates, but must not reset the chosen charges.
    tester
        .widget<HMBButtonPrimary>(
          find.widgetWithText(HMBButtonPrimary, 'Continue to invoice'),
        )
        .onPressed!();
    await pumpUntilFound(tester, find.byType(InvoiceOptionsScreen));
    await tester.pumpAndSettle();
    expect(find.text('Group labour by task'), findsOneWidget);
    expect(find.text('Create draft invoice'), findsOneWidget);
  });

  testWidgets(
    'waiver selection starts empty and cancel restores invoice selection',
    (tester) async {
      await mount(tester);
      tester
          .widget<HMBButtonSecondary>(
            find.widgetWithText(HMBButtonSecondary, 'Choose charges to waive'),
          )
          .onPressed!();
      await pumpUntilFound(tester, find.text(r'Selected to waive: 0 — $0.00'));
      await tester.pumpAndSettle();
      expect(find.text(r'Selected to waive: 0 — $0.00'), findsOneWidget);
      expect(
        tester
            .widget<HMBButtonPrimary>(
              find.widgetWithText(HMBButtonPrimary, 'Waive 0 selected charges'),
            )
            .onPressed,
        isNull,
      );
      final labour = tester
          .widgetList<HMBSwitch>(find.byType(HMBSwitch))
          .firstWhere((control) => control.labelText.contains('Labour:'));
      expect(labour.initialValue, isFalse);
      labour.onChanged(true);
      await tester.pumpAndSettle();
      expect(find.text(r'Selected to waive: 1 — $100.00'), findsOneWidget);
      tester
          .widget<HMBButtonSecondary>(
            find.widgetWithText(HMBButtonSecondary, 'Cancel waiver'),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.text(r'Total: $100.00'), findsOneWidget);
      await tester.runAsync(() async {
        expect(await DaoInvoice().getAll(), isEmpty);
        expect(await DaoJob().db.query('billing_waiver'), isEmpty);
      });
    },
  );

  testWidgets('schedule returns payments to the existing invoice review', (
    tester,
  ) async {
    await mount(tester);
    await split(tester);
    final add = tester.widget<HMBButtonAdd>(find.byType(HMBButtonAdd));
    await runAsyncAndPump(tester, () => add.onAdd!());
    await tester.pumpAndSettle();
    await runAsyncAndPump(tester, () => add.onAdd!());
    await tester.pumpAndSettle();
    final tiles = tester.widgetList<MilestoneTile>(find.byType(MilestoneTile));
    expect(tiles, hasLength(2));
    // The milestone invoice action returns to the existing review, rather
    // than opening a nested invoice preparation route.
    await runAsyncAndPump(
      tester,
      () => tiles.first.onInvoice(tiles.first.milestone),
    );
    await waitForRefresh(tester);
    expect(find.byType(PrepareInvoiceScreen), findsOneWidget);
    expect(find.byType(EditMilestonesScreen), findsNothing);
    expect(find.text('Split into milestones'), findsNothing);
    expect(find.textContaining('Labour: Extra repairs'), findsOneWidget);
    expect(find.text(r'Total: $600.00'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await DaoInvoice().getAll(), isEmpty);
    });
  });
}
