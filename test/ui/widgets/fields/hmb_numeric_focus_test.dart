@Tags(['flutter'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/fields/hmb_integer_field.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final zero in ['0', '0.000', r'$0.00', '0.000%']) {
    testWidgets('hides $zero on focus without changing its value', (
      tester,
    ) async {
      final controller = TextEditingController(text: zero);
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HMBTextField(
              controller: controller,
              labelText: 'Amount',
              focusNode: focus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text(zero), findsOneWidget);
      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      final editor = tester.widget<EditableText>(find.byType(EditableText));
      expect(editor.controller.text, isEmpty);
      expect(controller.text, zero);
      focus.unfocus();
      await tester.pump();
      expect(editor.controller.text, zero);
      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '12.5');
      expect(controller.text, '12.5');
      focus.unfocus();
      await tester.pump();
      expect(editor.controller.text, '12.5');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('untouched focused zero validates and saves as zero', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0');
    final key = GlobalKey<FormState>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: HMBIntegerField(
              controller: controller,
              labelText: 'Count',
              required: true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(key.currentState!.validate(), isTrue);
    expect(int.parse(controller.text), 0);
    await tester.enterText(find.byType(TextFormField), '5');
    await tester.enterText(find.byType(TextFormField), '');
    expect(controller.text, isEmpty);
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('nonzero values and ordinary text zeros stay visible', (
    tester,
  ) async {
    final number = TextEditingController(text: '42');
    final text = TextEditingController(text: '0');
    addTearDown(number.dispose);
    addTearDown(text.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HMBTextField(
                controller: number,
                labelText: 'Count',
                keyboardType: TextInputType.number,
              ),
              HMBTextField(controller: text, labelText: 'Name'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      '42',
    );
    await tester.tap(find.byType(TextFormField).last);
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pasting replaces a hidden zero', (tester) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': '25'} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBTextField(
            controller: controller,
            labelText: 'Count',
            keyboardType: TextInputType.number,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    await (Actions.invoke(
          tester.element(find.byType(EditableText)),
          const PasteIntent(),
        )
        as Future<void>?);
    await tester.pump();
    expect(controller.text, '25');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('external controller updates reach the focused editor', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBTextField(
            controller: controller,
            labelText: 'Count',
            keyboardType: TextInputType.number,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    controller.text = '35';
    await tester.pump();
    expect(find.text('35'), findsOneWidget);
    expect(controller.text, '35');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
