import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/task/task_instructions_screen.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/ui/widgets/widgets.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui_test_helpers.dart';

void main() {
  for (final reviewFirst in [false, true]) {
    testWidgets('cancelling leaves tasks unsaved: $reviewFirst', (
      tester,
    ) async {
      var saves = 0;
      await openWizard(tester, save: (_) async => ++saves);
      if (reviewFirst) {
        await propose(tester);
        expect(find.text('Review tasks'), findsOneWidget);
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Open instructions'), findsOneWidget);
      expect(saves, 0);
      await drain(tester);
    });
  }

  testWidgets('review edits and selection are saved only on explicit save', (
    tester,
  ) async {
    List<TaskInstructionDraft>? saved;
    await openWizard(
      tester,
      save: (drafts) async {
        saved = drafts;
        return drafts.length;
      },
    );
    await propose(tester);
    expect(saved, isNull);
    await tester.enterText(field('Task name').first, 'Repair kitchen tap');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Task 2'));
    await tester.tap(find.text('Save tasks'));
    await tester.pumpAndSettle();
    expect(saved!.map((draft) => draft.name), ['Repair kitchen tap']);
    expect(find.text('Open instructions'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('rapid saves apply a reviewed draft once', (tester) async {
    final saved = Completer<int>();
    var calls = 0;
    await openWizard(
      tester,
      save: (_) {
        calls++;
        return saved.future;
      },
    );
    await propose(tester);
    final button = tester.widget<HMBButtonPrimary>(
      find.widgetWithText(HMBButtonPrimary, 'Save tasks'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(calls, 1);
    saved.complete(2);
    await tester.pumpAndSettle();
    expect(calls, 1);
    await drain(tester);
  });

  testWidgets('analysis failure keeps pasted instructions and can retry', (
    tester,
  ) async {
    var analyses = 0;
    await openWizard(
      tester,
      analyze: (instructions) async {
        expect(instructions, 'Also repair the tap and fence.');
        if (++analyses == 1) {
          throw StateError('Unavailable');
        }
        return suggestions;
      },
    );
    await propose(tester);
    expect(
      find.textContaining('Could not prepare suggestions'),
      findsOneWidget,
    );
    expect(find.text('Also repair the tap and fence.'), findsOneWidget);
    await tester.tap(find.text('Propose tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Review tasks'), findsOneWidget);
    expect(analyses, 2);
    await drain(tester);
  });
}

const suggestions = [
  TaskInstructionDraft(name: 'Repair tap', description: 'Replace washer.'),
  TaskInstructionDraft(name: 'Repair fence'),
];

Future<void> openWizard(
  WidgetTester tester, {
  AnalyzeTaskInstructions? analyze,
  SaveTaskInstructions? save,
}) async {
  final job = Job.forInsert(
    customerId: 1,
    summary: 'Existing job',
    description: '',
    siteId: 1,
    contactId: 1,
    billingContactId: 1,
    status: JobStatus.inProgress,
    hourlyRate: MoneyEx.zero,
    bookingFee: MoneyEx.zero,
  );
  await tester.pumpWidget(
    MaterialApp(
      builder: (_, child) => Stack(children: [child!, const BlockingOverlay()]),
      home: Scaffold(
        body: Builder(
          builder: (context) => HMBButton(
            label: 'Open instructions',
            hint: 'Open instructions',
            onPressed: () async {
              await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => TaskInstructionsScreen(
                    job: job,
                    analyze: analyze ?? (_) async => suggestions,
                    save: save ?? (drafts) async => drafts.length,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open instructions'));
  await tester.pumpAndSettle();
  await pumpDeferredStates(tester);
}

Future<void> propose(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).first,
    'Also repair the tap and fence.',
  );
  await tester.tap(find.text('Propose tasks'));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is HMBTextField && widget.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

Future<void> drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 11));
}
