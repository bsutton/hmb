@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/operating_hours.dart';
import 'package:hmb/ui/crud/system/operating_hours_ui.dart';
import 'package:hmb/ui/crud/system/system_business_screen.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  testWidgets('business details form has screen edge padding', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SystemBusinessScreen()));
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView));

    expect(listView.padding, const EdgeInsets.all(16));
  });

  testWidgets('business details fits phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: SystemBusinessScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('operating day labels use high contrast colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OperatingHoursUi(
              controller: OperatingHoursController(
                operatingHours: OperatingHours.fromJson(null),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = tester.widget<ToggleButtons>(find.byType(ToggleButtons));

    expect(toggle.color, HMBColors.textPrimary);
    expect(toggle.selectedColor, Colors.black);
    expect(toggle.fillColor, HMBColors.primary);
  });
}
