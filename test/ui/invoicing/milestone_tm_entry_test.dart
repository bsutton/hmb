import 'package:deferred_state/deferred_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/base_full_screen/list_entity_screen.dart';
import 'package:hmb/ui/invoicing/list_invoice_screen.dart';
import 'package:hmb/ui/invoicing/prepare_invoice_screen.dart';
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

  testWidgets('job invoice list Add offers T&M after final milestone', (
    tester,
  ) async {
    late MilestoneTmFixture f;
    await tester.runAsync(() async {
      f = await MilestoneTmFixture.create();
      await f.invoiceMilestone(0);
      final task = await f.addVariation();
      await f.addLabour(task);
      await f.invoiceMilestone(1);
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        // The job's Invoice dashlet opens this restricted list.
        home: Scaffold(body: InvoiceListScreen(jobRestriction: f.job)),
      ),
    );
    final list = tester.state<EntityListScreenState<Invoice>>(
      find.byType(EntityListScreen<Invoice>),
    );
    await runAsyncAndPump(tester, () => list.initialised);
    await pumpReadOnlyFutureBuilders(tester, find.byType(InvoiceListScreen));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HMBButtonAdd).first);
    await pumpUntilFound(tester, find.byType(PrepareInvoiceScreen));
    final review = tester.state<DeferredState<PrepareInvoiceScreen>>(
      find.byType(PrepareInvoiceScreen),
    );
    await runAsyncAndPump(tester, () => review.initialised);
    await tester.pumpAndSettle();
    expect(find.text('Review charges'), findsOneWidget);
    expect(find.text('Total: ${MoneyEx.dollars(176)}'), findsOneWidget);
    expect(find.textContaining('Labour:'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await pumpReadOnlyFutureBuilders(tester, find.byType(InvoiceListScreen));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
