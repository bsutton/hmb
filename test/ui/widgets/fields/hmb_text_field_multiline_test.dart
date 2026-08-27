@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('supports an expanded multiline editing area', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBTextField(
            controller: controller,
            labelText: 'Description',
            keyboardType: TextInputType.multiline,
            minLines: 2,
            maxLines: 4,
          ),
        ),
      ),
    );

    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.minLines, 2);
    expect(field.maxLines, 4);
  });
}
