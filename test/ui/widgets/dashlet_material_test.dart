import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/nav/dashboards/dashlet_card.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('dashlet owns the Material surface for its tap handler', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 160,
            child: DashletCard<int>.onTap(
              label: 'Jobs',
              hint: 'Open jobs',
              icon: Icons.work,
              value: () async => const DashletValue(2),
              onTap: (_) => tapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tapped, isTrue);
  });
}
