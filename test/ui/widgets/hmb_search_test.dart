@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/hmb_search.dart';
import 'package:hmb/ui/widgets/icons/hmb_add_button.dart';
import 'package:hmb/ui/widgets/icons/hmb_clear_icon.dart';
import 'package:hmb/ui/widgets/select/hmb_filter_line.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('focused search expands and retains clear action', (
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
              TextButton(
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: const Text('Outside'),
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
    await tester.tap(find.text('Outside'));
    await tester.pumpAndSettle();
    expect(find.byType(HMBButtonAdd), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    // An externally supplied controller remains owned by its caller.
    controller
      ..text = 'Still usable'
      ..dispose();
  });
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
}
