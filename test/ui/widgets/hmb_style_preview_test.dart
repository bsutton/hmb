import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../../tool/style_preview.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('shared style works at 320px with text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: HMBTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const HMBStylePreview(),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('preview-contact')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('preview-contact')),
        'Sam Taylor',
      );
      expect(find.text('Sam Taylor'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Add party'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add party'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      // Build every preview section, including lazy children below the fold.
      await tester.scrollUntilVisible(
        find.text('Related content in a labelled container.'),
        300,
        maxScrolls: 100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preview validation, selections and actions are interactive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: HMBTheme.dark, home: const HMBStylePreview()),
    );

    Future<void> reveal(Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        maxScrolls: 100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    await reveal(find.text('Validate fields'));
    await tester.tap(find.text('Validate fields'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a Summary'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('preview-required')),
      'Repair hallway',
    );
    await reveal(find.text('Validate fields'));
    await tester.tap(find.text('Validate fields'));
    await tester.pumpAndSettle();
    expect(find.text('All fields are valid.'), findsOneWidget);

    await reveal(find.byKey(const ValueKey('preview-role')));
    await tester.tap(find.byKey(const ValueKey('preview-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Authoriser'));
    await tester.pumpAndSettle();
    expect(find.text('Authoriser'), findsOneWidget);

    await reveal(find.text('High'));
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    await reveal(find.text('Priority: High · Notifications: off'));
    expect(find.text('Priority: High · Notifications: off'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Toggle notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Toggle notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Priority: High · Notifications: on'), findsOneWidget);

    await reveal(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await reveal(find.text('Save tapped'));
    expect(find.text('Save tapped'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
