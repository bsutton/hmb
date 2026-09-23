@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';
import 'package:hmb/ui/widgets/icons/hmb_add_button.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('add link creates and selects once without a dialog plus', (
    tester,
  ) async {
    String? selected;
    var creates = 0;
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: form,
            child: HMBDroplist<String>(
              title: 'Job',
              selectedItem: () async => selected,
              items: (_) async => ['New job'],
              format: (item) => item,
              onChanged: (item) => selected = item,
              onAdd: () async {
                creates++;
                selected = 'New job';
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final link = find.byType(HMBActionLink);
    expect(link, findsOneWidget);
    expect(
      tester.getTopLeft(link).dy,
      greaterThan(tester.getBottomLeft(find.text('Select a Job')).dy),
    );
    expect(
      tester.widget<Text>(find.text('Add Job')).style!.decoration,
      TextDecoration.underline,
    );
    await tester.tap(find.text('Add Job'));
    await tester.pumpAndSettle();
    expect(creates, 1);
    expect(find.text('New job'), findsOneWidget);
    expect(form.currentState!.validate(), isTrue);
    await tester.tap(find.text('New job'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(HMBButtonAdd), findsNothing);
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('Add Job')),
      findsNothing,
    );
  });
}
