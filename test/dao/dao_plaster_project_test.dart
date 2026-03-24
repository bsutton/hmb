import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import 'invoice/utility.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('persists project rooms lines openings and material sizes', () async {
    final job = await createJob(
      DateTime.now(),
      BillingType.fixedPrice,
      hourlyRate: Money.fromInt(5000, isoCode: 'AUD'),
      summary: 'Plasterboard Job',
    );
    final task = await createTask(job, 'Ceiling');
    final supplier = Supplier.forInsert(
      name: 'Plaster Supply',
      businessNumber: '',
      description: '',
      bsb: '',
      accountNumber: '',
      service: '',
    );
    await DaoSupplier().insert(supplier);

    final project = PlasterProject.forInsert(
      name: 'Plaster Plan',
      jobId: job.id,
      taskId: task.id,
      supplierId: supplier.id,
      wastePercent: 15,
    );
    await DaoPlasterProject().insert(project);

    final savedProject = (await DaoPlasterProject().getByFilter(
      'Plaster Plan',
    )).single;
    final room = PlasterRoom.forInsert(
      projectId: savedProject.id,
      name: 'Room 1',
      unitSystem: PreferredUnitSystem.metric,
      ceilingHeight: PlasterGeometry.defaultCeilingHeight(
        PreferredUnitSystem.metric,
      ),
    );
    await DaoPlasterRoom().insert(room);
    final savedRoom = (await DaoPlasterRoom().getByProject(
      savedProject.id,
    )).single;

    final lines = PlasterGeometry.defaultLines(
      roomId: savedRoom.id,
      unitSystem: savedRoom.unitSystem,
    );
    for (final line in lines) {
      await DaoPlasterRoomLine().insert(line);
    }
    final savedLines = await DaoPlasterRoomLine().getByRoom(savedRoom.id);

    final opening = PlasterRoomOpening.forInsert(
      lineId: savedLines.first.id,
      type: PlasterOpeningType.door,
      offsetFromStart: 0,
      width: PlasterGeometry.fromDisplay(0.82, savedRoom.unitSystem),
      height: PlasterGeometry.fromDisplay(2.04, savedRoom.unitSystem),
      sillHeight: 0,
    );
    await DaoPlasterRoomOpening().insert(opening);

    final material = PlasterMaterialSize.forInsert(
      supplierId: supplier.id,
      name: '1200 x 2400',
      unitSystem: PreferredUnitSystem.metric,
      width: 12000,
      height: 24000,
    );
    await DaoPlasterMaterialSize().insert(material);

    final reloadedProjects = await DaoPlasterProject().getByFilter('Plaster');
    final reloadedRooms = await DaoPlasterRoom().getByProject(savedProject.id);
    final reloadedLines = await DaoPlasterRoomLine().getByRoom(savedRoom.id);
    final reloadedOpenings = await DaoPlasterRoomOpening().getByLineIds(
      reloadedLines.map((line) => line.id).toList(),
    );
    final reloadedMaterials = await DaoPlasterMaterialSize().getBySupplier(
      supplier.id,
    );

    expect(reloadedProjects, hasLength(1));
    expect(reloadedProjects.single.taskId, task.id);
    expect(reloadedProjects.single.supplierId, supplier.id);
    expect(reloadedRooms, hasLength(1));
    expect(reloadedRooms.single.unitSystem, PreferredUnitSystem.metric);
    expect(reloadedLines, hasLength(4));
    expect(reloadedLines.first.seqNo, 0);
    expect(reloadedLines.last.seqNo, 3);
    expect(reloadedOpenings, hasLength(1));
    expect(reloadedOpenings.single.type, PlasterOpeningType.door);
    expect(reloadedMaterials, hasLength(1));
    expect(reloadedMaterials.single.name, '1200 x 2400');
    expect(reloadedMaterials.single.supplierId, supplier.id);
  });
}
