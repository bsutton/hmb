import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_area.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/ui/widgets/layout/hmb_form_section.dart';
import 'package:hmb/ui/widgets/layout/hmb_spacing.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('nested sections have one parent gap and no outside space', (
    tester,
  ) async {
    const first = Key('first');
    const second = Key('second');
    const third = Key('third');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HMBFormSection(
            spacing: HMBSpacing.kSectionGap,
            children: [
              HMBFormSection(
                children: [
                  SizedBox(key: first, height: 40),
                  SizedBox(key: second, height: 40),
                ],
              ),
              SizedBox(key: third, height: 40),
            ],
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(first)).dy, 0);
    expect(
      tester.getTopLeft(find.byKey(second)).dy -
          tester.getBottomLeft(find.byKey(first)).dy,
      HMBSpacing.kFieldGap,
    );
    expect(
      tester.getTopLeft(find.byKey(third)).dy -
          tester.getBottomLeft(find.byKey(second)).dy,
      HMBSpacing.kSectionGap,
    );
  });

  testWidgets('multiline fields leave their outside spacing to the form', (
    tester,
  ) async {
    final title = TextEditingController();
    final notes = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(notes.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HMBFormSection(
            children: [
              HMBTextField(controller: title, labelText: 'Title'),
              HMBTextArea(controller: notes, labelText: 'Notes'),
            ],
          ),
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    expect(
      tester.getTopLeft(fields.at(1)).dy -
          tester.getBottomLeft(fields.first).dy,
      HMBSpacing.kFieldGap,
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('form scrolls and keeps validation clear at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final form = GlobalKey<FormState>();
      final controllers = List.generate(6, (_) => TextEditingController());
      addTearDown(() {
        for (final c in controllers) {
          c.dispose();
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: HMBTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Form(
              key: form,
              child: HMBFormList(
                children: [
                  for (var i = 0; i < controllers.length; i++)
                    HMBTextField(
                      controller: controllers[i],
                      labelText: 'Field $i',
                      required: true,
                    ),
                  const Text('End of form'),
                ],
              ),
            ),
          ),
        ),
      );
      final fields = find.byType(HMBTextField);
      expect(tester.getTopLeft(fields.first).dx, HMBSpacing.kPageInset);
      form.currentState!.validate();
      await tester.pump();
      expect(find.text('Please enter a Field 0'), findsOneWidget);
      expect(
        tester.getTopLeft(fields.at(1)).dy -
            tester.getBottomLeft(fields.first).dy,
        HMBSpacing.kFieldGap,
      );
      await tester.scrollUntilVisible(
        find.text('End of form'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('End of form').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
