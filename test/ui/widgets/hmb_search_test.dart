@Tags(['flutter'])
library;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/hmb_search.dart';
import 'package:hmb/ui/widgets/icons/hmb_add_button.dart';
import 'package:hmb/ui/widgets/icons/hmb_clear_icon.dart';
import 'package:hmb/ui/widgets/layout/hmb_spacing.dart';
import 'package:hmb/ui/widgets/select/hmb_filter_line.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('search retracts after clear and outside $kind taps', (
      tester,
    ) async {
      final controller = HMBSearchController();
      final searches = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                HMBFilterLine(
                  lineBuilder: (_) => HMBSearchWithAdd(
                    controller: controller,
                    onSearch: searches.add,
                    onAdd: () {},
                  ),
                  sheetBuilder: (_) => const Text('Filters'),
                  onReset: null,
                  isActive: () => false,
                ),
                const Expanded(
                  child: ColoredBox(
                    key: ValueKey('outside-search'),
                    color: Colors.white,
                    child: SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final search = find.byType(TextFormField);
      final initialWidth = tester.getSize(search).width;
      expect(find.byType(HMBButtonAdd), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      await tester.tap(search);
      await tester.pumpAndSettle();
      expect(find.byType(HMBButtonAdd), findsNothing);
      expect(find.byIcon(Icons.tune), findsNothing);
      expect(tester.getSize(search).width, greaterThan(initialWidth));
      expect(tester.getTopRight(search).dx, 800);
      await tester.enterText(search, ' PAINT ');
      await tester.pump(const Duration(milliseconds: 350));
      expect(searches.last, 'paint');
      await tester.tap(find.byType(HMBClearIcon));
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(searches.last, isNull);
      expect(find.byType(HMBButtonAdd), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(tester.getSize(search).width, initialWidth);
      await tester.tap(search);
      await tester.enterText(search, 'Keep this filter');
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(HMBButtonAdd), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('outside-search')),
        kind: kind,
      );
      await tester.pumpAndSettle();
      expect(find.byType(HMBButtonAdd), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(controller.text, 'Keep this filter');
      expect(searches.last, 'keep this filter');
      await tester.pumpWidget(const SizedBox.shrink());
      // An externally supplied controller remains owned by its caller.
      controller
        ..text = 'Still usable'
        ..dispose();
    });
  }
  testWidgets('search with add leaves trailing screen padding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 393,
            child: HMBSearchWithAdd(onSearch: (_) {}, onAdd: () {}),
          ),
        ),
      ),
    );

    final addRight = tester.getTopRight(find.byIcon(Icons.add)).dx;

    expect(393 - addRight, greaterThanOrEqualTo(8));
  });
  for (final width in [320.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('search Add spacing at $width pixels and $scale scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var additions = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: HMBFilterLine(
                lineBuilder: (_) => HMBSearchWithAdd(
                  onSearch: (_) {},
                  onAdd: () => additions++,
                ),
                sheetBuilder: (_) => const Text('Filters'),
                onReset: null,
                isActive: () => false,
              ),
            ),
          ),
        );
        final search = find.byType(TextFormField);
        final add = find.byType(HMBButtonAdd);
        expect(
          tester.getTopLeft(add).dx - tester.getTopRight(search).dx,
          HMBSpacing.kRelated,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(add);
        expect(additions, 1);
        await tester.tap(search);
        await tester.pumpAndSettle();
        expect(add, findsNothing);
        expect(tester.getSize(search).width, width);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('hidden Add leaves the full width available for search', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBSearchWithAdd(
            showAdd: false,
            onSearch: (_) {},
            onAdd: () {},
          ),
        ),
      ),
    );
    expect(find.byType(HMBButtonAdd), findsNothing);
    expect(tester.getSize(find.byType(TextFormField)).width, 800);
  });
}
