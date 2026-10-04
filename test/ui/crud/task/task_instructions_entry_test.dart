@Tags(['flutter'])
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/base_nested/list_nested_screen.dart';
import 'package:hmb/ui/crud/task/list_task_screen.dart';
import 'package:hmb/ui/crud/task/task_instructions_screen.dart';
import 'package:hmb/ui/widgets/blocking_ui.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });

  tearDown(tearDownTestDb);

  testWidgets('instructions add reviewed tasks to the current job', (
    tester,
  ) async {
    final job = await runAsyncAndPump(
      tester,
      () => createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        status: JobStatus.inProgress,
      ),
    );
    String? analyzedInstructions;
    List<TaskInstructionDraft>? savedTasks;
    int? savedCount;

    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: Scaffold(
          body: TaskListScreen(
            parent: Parent(job),
            extended: true,
            analyzeInstructions: (instructions) async {
              analyzedInstructions = instructions;
              return const [
                TaskInstructionDraft(
                  name: 'Replace tap washer',
                  description: 'Repair the kitchen tap.',
                ),
              ];
            },
            saveInstructions: (drafts) async {
              savedTasks = drafts;
              return drafts.length;
            },
            onInstructionsSaved: (count) => savedCount = count,
          ),
        ),
      ),
    );
    await pumpDeferredStates(tester);

    await tester.tap(find.text('Add from Instructions'));
    await tester.pumpAndSettle();
    await pumpDeferredStates(tester);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Please repair the leaking kitchen tap.',
    );
    await tester.tap(find.text('Propose tasks'));
    await tester.pumpAndSettle();

    expect(analyzedInstructions, 'Please repair the leaking kitchen tap.');
    expect(find.text('Review tasks'), findsOneWidget);
    await tester.tap(find.text('Save tasks'));
    await pumpUntilCondition(
      tester,
      () => savedCount != null,
      'instructions save completion',
    );

    expect(savedTasks, hasLength(1));
    final saved = savedTasks!;
    expect(saved.single.name, 'Replace tap washer');
    expect(saved.single.description, 'Repair the kitchen tap.');
    expect(savedCount, 1);
    expect(find.text('Add from Instructions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
