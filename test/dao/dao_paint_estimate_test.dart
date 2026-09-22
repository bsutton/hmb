import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/dao_paint_estimate.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/paint_estimate.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);
  test(
    'painting assumptions persist without changing the source room',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: MoneyEx.dollars(90),
      );
      final project = PlasterProject.forInsert(
        name: 'Plan',
        jobId: job.id,
        wastePercent: 10,
      );
      await DaoPlasterProject().insert(project);
      final room = PlasterRoom.forInsert(
        projectId: project.id,
        name: 'Room',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
        plasterCeiling: false,
      );
      await DaoPlasterRoom().insert(room);
      final before = room.toMap();
      final settings = await DaoPaintEstimate().get(room.id);
      settings.preparationRates[PaintPreparation.dusting] = 0.25;
      await DaoPaintEstimate().save(room.id, settings);
      expect(
        (await DaoPaintEstimate().get(
          room.id,
        )).preparationRates[PaintPreparation.dusting],
        0.25,
      );
      expect((await DaoPlasterRoom().getById(room.id))!.toMap(), before);
    },
  );
}
