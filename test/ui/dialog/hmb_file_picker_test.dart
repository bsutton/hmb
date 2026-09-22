import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/dialog/hmb_file_picker_linux.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('file picker searches names and accepts full supported paths', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('hmb-picker-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final pdf = File(p.join(directory.path, 'invoice.pdf'))
      ..writeAsStringSync('');
    File(p.join(directory.path, 'notes.txt')).writeAsStringSync('');
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await HMBFilePickerDialog().show(
                  context,
                  initialDirectory: directory,
                  allowedExtensions: ['pdf'],
                );
              },
              child: const Text('Choose'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(find.text('invoice.pdf'), findsOneWidget);
    expect(find.text('notes.txt'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Search this folder'),
      'missing',
    );
    await tester.pump();
    expect(find.text('invoice.pdf'), findsNothing);
    final path = find.widgetWithText(TextFormField, 'Folder or full file path');
    await tester.enterText(path, p.join(directory.path, 'notes.txt'));
    await tester.tap(find.byTooltip('Open path'));
    await tester.pump();
    expect(
      find.text('Enter an existing folder or a supported file.'),
      findsOneWidget,
    );
    await tester.enterText(path, pdf.path);
    await tester.tap(find.byTooltip('Open path'));
    await tester.pumpAndSettle();
    expect(selected, pdf.path);
    expect(tester.takeException(), isNull);
  });
}
