@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/fields/hmb_secret_field.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('masks by default and toggles without changing the value', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'test-only-key');
    addTearDown(controller.dispose);
    var changes = 0;
    controller.addListener(() => changes++);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBSecretField(
            controller: controller,
            labelText: 'API Key',
            suffixIcon: IconButton(
              tooltip: 'Generate token',
              onPressed: () {},
              icon: const Icon(Icons.auto_fix_high),
            ),
          ),
        ),
      ),
    );
    bool masked() =>
        tester.widget<EditableText>(find.byType(EditableText)).obscureText;
    expect(masked(), isTrue);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(find.byTooltip('Generate token'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Show API Key'));
      await tester.pump();
      expect(masked(), isFalse);
      await tester.tap(find.byTooltip('Hide API Key'));
      await tester.pump();
      expect(masked(), isTrue);
    }
    expect(controller.text, 'test-only-key');
    expect(changes, 0);
  });

  testWidgets('new screen masks again and disabled fields cannot reveal', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'test-only-key');
    addTearDown(controller.dispose);
    Widget screen({bool enabled = true}) => MaterialApp(
      home: Scaffold(
        body: HMBSecretField(
          controller: controller,
          labelText: 'API Key',
          enabled: enabled,
        ),
      ),
    );
    await tester.pumpWidget(screen());
    await tester.tap(find.byTooltip('Show API Key'));
    await tester.pump();
    await tester.pumpWidget(screen(enabled: false));
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(screen());
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
  });
}
