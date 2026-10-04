import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/tools/trip_log_screen.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/ui/widgets/layout/hmb_form_section.dart';
import 'package:hmb/ui/widgets/layout/hmb_spacing.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/widgets.g.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../database/management/db_utility_test_helper.dart';
import 'crud/job/job_summary_editor_test.dart' show pumpUntil;

void main() {
  testWidgets('trip log starts off and supports custom reporting dates', (
    tester,
  ) async {
    await tester.runAsync(setupTestDb);
    addTearDown(tearDownTestDb);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: const TripLogScreen(),
      ),
    );
    await pumpUntil(tester, find.text('Trip logging is off'));
    tester
        .widget<HMBDroplist<String>>(find.byType(HMBDroplist<String>))
        .onChanged('Custom');
    await pumpUntil(tester, find.byType(HMBDateTimeField));
    expect(find.byType(HMBDateTimeField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('trip settings scroll and validate at 320px, scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(setupTestDb);
      addTearDown(tearDownTestDb);
      await tester.pumpWidget(
        MaterialApp(
          theme: HMBTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Stack(children: [child!, const BlockingOverlay()]),
          ),
          home: const TripLogScreen(),
        ),
      );
      for (var attempt = 0; attempt < 200; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 1));
        if (find.byType(HMBFormList).evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.byType(HMBFormList), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Travel settings').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Travel settings'));
      await tester.pumpAndSettle();
      final rate = find.byWidgetPredicate(
        (widget) =>
            widget is HMBTextField &&
            widget.labelText == 'Cost per km (your own rate)',
      );
      await tester.scrollUntilVisible(
        rate,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(rate, '-1');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save settings').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save settings'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a non-negative rate'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Refresh trips'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final refresh = find.widgetWithText(HMBButtonSecondary, 'Refresh trips');
      final retry = find.widgetWithText(
        HMBButtonSecondary,
        'Retry road distances',
      );
      expect(
        tester.getTopLeft(retry).dy - tester.getBottomLeft(refresh).dy,
        HMBSpacing.kFieldGap,
      );
      await tester.scrollUntilVisible(
        find.text('No trips in this period.').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('No trips in this period.').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
