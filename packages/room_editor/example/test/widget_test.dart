import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_editor/room_editor.dart';
import 'package:room_editor_example/main.dart';

void main() {
  testWidgets('renders room editor harness', (WidgetTester tester) async {
    await tester.pumpWidget(const RoomEditorExampleApp());

    expect(find.text('Room Editor Browser Harness'), findsOneWidget);
    expect(find.text('Current geometry'), findsOneWidget);
    expect(find.text('Constraints'), findsOneWidget);
  });

  testWidgets('length dialog opens when a line is preselected', (
    WidgetTester tester,
  ) async {
    final selectionController = RoomEditorSelectionController(
      RoomEditorSelection(selectedLineIndex: 0),
    );
    final document = RoomEditorDocument(
      bundle: buildRoomEditorBundle(
        roomName: 'Test',
        unitSystem: RoomEditorUnitSystem.metric,
        plasterCeiling: true,
        lines: const [
          (
            id: 1,
            seqNo: 1,
            startX: 0,
            startY: 0,
            length: 3600
          ),
          (
            id: 2,
            seqNo: 2,
            startX: 3600,
            startY: 0,
            length: 2400
          ),
          (
            id: 3,
            seqNo: 3,
            startX: 3600,
            startY: 2400,
            length: 3600
          ),
          (
            id: 4,
            seqNo: 4,
            startX: 0,
            startY: 2400,
            length: 2400
          ),
        ],
        openings: const [],
      ),
      constraints: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomEditorWorkspace(
            document: document,
            selectionController: selectionController,
            onDocumentCommitted: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.straighten));
    await tester.pumpAndSettle();

    expect(find.text('Set Length'), findsOneWidget);
  });
}
