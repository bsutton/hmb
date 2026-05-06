import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/save_and_close.dart';

void main() {
  testWidgets('new entities save without closing', (tester) async {
    bool? closeValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveAndClose(
            showSaveOnly: true,
            onSave: ({required close}) async => closeValue = close,
            onCancel: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Save & Close'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(closeValue, isFalse);
  });

  testWidgets('existing entities save and close', (tester) async {
    bool? closeValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveAndClose(
            showSaveOnly: false,
            onSave: ({required close}) async => closeValue = close,
            onCancel: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Save & Close'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(closeValue, isTrue);
  });
}
