import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_editor/room_editor.dart';

void main() {
  testWidgets('length constraint dialog saves a driving length', (
    tester,
  ) async {
    RoomEditorLengthConstraintDraft? result;
    await _pumpLengthDialogHost(tester, onResult: (value) => result = value);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Driven'), findsOneWidget);
    expect(find.text('Driving'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '3600');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result?.mode, RoomEditorLengthConstraintMode.driving);
    expect(result?.length, 36000);
  });

  testWidgets('length constraint dialog can switch to driven', (tester) async {
    RoomEditorLengthConstraintDraft? result;
    await _pumpLengthDialogHost(tester, onResult: (value) => result = value);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Driven'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result?.mode, RoomEditorLengthConstraintMode.driven);
    expect(result?.length, 24000);
  });
}

Future<void> _pumpLengthDialogHost(
  WidgetTester tester, {
  required ValueChanged<RoomEditorLengthConstraintDraft?> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            onResult(
              await showRoomEditorLengthConstraintDialog(
                context: context,
                unitSystem: RoomEditorUnitSystem.metric,
                initialValue: 24000,
                initialMode: RoomEditorLengthConstraintMode.driving,
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}
