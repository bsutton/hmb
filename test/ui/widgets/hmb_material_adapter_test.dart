import 'package:calendar_view/calendar_view.dart';
// calendar_view uses Flutter Material types, distinct from material_ui.
// ignore: migrate_design_widgets
import 'package:flutter/material.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/widgets/hmb_material_adapter.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('calendar renders and opens its matching Material date picker', (
    tester,
  ) async {
    final controller = EventController<String>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: HMBTheme.dark,
        builder: (context, child) => HMBMaterialAdapter(child: child!),
        home: Scaffold(
          body: CalendarControllerProvider<String>(
            controller: controller,
            child: DayView<String>(
              initialDay: DateTime(2026, 9, 22),
              minDay: DateTime(2026),
              maxDay: DateTime(2027),
              dateStringBuilder: (date, {secondaryDate}) => 'Calendar date',
              backgroundColor: HMBColors.defaultBackground,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final calendarContext = tester.element(find.byType(DayView<String>));
    expect(
      flutter.Theme.of(calendarContext).colorScheme.primary,
      HMBColors.primary,
    );
    await tester.tap(find.text('Calendar date'));
    await tester.pumpAndSettle();
    expect(find.byType(flutter.DatePickerDialog), findsOneWidget);
    final dialogContext = tester.element(find.byType(flutter.DatePickerDialog));
    expect(
      flutter.Theme.of(dialogContext).colorScheme.surface,
      HMBColors.surface4dp,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(flutter.DatePickerDialog), findsNothing);
  });
}
