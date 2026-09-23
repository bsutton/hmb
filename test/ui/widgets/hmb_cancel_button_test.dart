@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Cancel stays outlined and respects disabled state', (
    tester,
  ) async {
    var presses = 0;
    for (final enabled in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HMBCancelButton(enabled: enabled, onPressed: () => presses++),
          ),
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(presses, 1);
    }
  });
}
