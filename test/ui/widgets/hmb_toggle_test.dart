import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/hmb_toggle.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('toggle fits an unconstrained calendar toolbar row', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: HMBTheme.dark,
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('Today')),
              HMBToggle(
                label: 'Extended',
                hint: 'Show full 24 hrs',
                initialValue: false,
                onToggled: (value) => selected = value,
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Show full 24 hrs'));
    await tester.pump();
    expect(selected, isTrue);
    expect(find.byIcon(Icons.toggle_on), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggle label wraps in a narrow form with enlarged text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HMBTheme.dark,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SizedBox(
              width: 180,
              child: HMBToggle(
                label: 'Extended hours',
                hint: 'Show full 24 hrs',
                initialValue: false,
                onToggled: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Extended hours'), findsOneWidget);
  });
}
