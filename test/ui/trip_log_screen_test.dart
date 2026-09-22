import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/tools/trip_log_screen.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/widgets.g.dart';
import 'package:material_ui/material_ui.dart';

import '../database/management/db_utility_test_helper.dart';
import 'crud/job/job_summary_editor_test.dart' show pumpUntil;

void main() {
  testWidgets('trip log starts off and supports custom reporting dates', (
    tester,
  ) async {
    await tester.runAsync(setupTestDb);
    addTearDown(tearDownTestDb);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: const TripLogScreen(),
      ),
    );
    await pumpUntil(tester, find.text('Trip logging is off'));
    tester
        .widget<HMBDroplist<String>>(find.byType(HMBDroplist<String>))
        .onChanged('Custom');
    await pumpUntil(tester, find.byType(HMBDateTimeField));
    expect(find.byType(HMBDateTimeField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
