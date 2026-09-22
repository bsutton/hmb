import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/dao_paint_estimate.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/tools/paint_estimator_screen.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/widgets.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';
import 'package:material_ui/material_ui.dart';

import '../database/management/db_utility_test_helper.dart';
import 'crud/job/job_summary_editor_test.dart' show pumpUntil;
import 'ui_test_helpers.dart';

void main() {
  testWidgets('existing CAD room can calculate and save a paint estimate', (
    tester,
  ) async {
    late PlasterProject project;
    late PlasterRoom room;
    await tester.runAsync(() async {
      await setupTestDb();
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: MoneyEx.dollars(90),
      );
      project = PlasterProject.forInsert(
        name: 'Plan',
        jobId: job.id,
        wastePercent: 10,
      );
      await DaoPlasterProject().insert(project);
      room = PlasterRoom.forInsert(
        projectId: project.id,
        name: 'Room',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
      );
      await DaoPlasterRoom().insert(room);
      for (final line in PlasterGeometry.defaultLines(
        roomId: room.id,
        unitSystem: room.unitSystem,
      )) {
        await DaoPlasterRoomLine().insert(line);
      }
    });
    addTearDown(tearDownTestDb);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: PaintEstimatorScreen(project: project),
      ),
    );
    await pumpUntil(tester, find.byType(HMBDroplist<PlasterRoom>));
    tester
        .widget<HMBDroplist<PlasterRoom>>(find.byType(HMBDroplist<PlasterRoom>))
        .onChanged(room);
    await pumpUntil(tester, find.text('Paint surfaces'));
    await tester.scrollUntilVisible(
      find.text('Save and calculate'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and calculate'));
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 50; attempt++) {
        final rows = await testDb!.query('paint_room_estimate');
        if (rows.isNotEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(await testDb!.query('paint_room_estimate'), hasLength(1));
      expect((await DaoPaintEstimate().get(room.id)).coats, 2);
    });
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Copy estimate'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Copy estimate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
