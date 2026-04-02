import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';
import 'package:hmb/util/dart/plaster_sheet_direction.dart';

void main() {
  group('PlasterGeometry', () {
    test('default imperial room uses 10ft square and 8ft ceiling', () {
      expect(
        PlasterGeometry.defaultRoomSize(PreferredUnitSystem.imperial),
        120000,
      );
      expect(
        PlasterGeometry.defaultCeilingHeight(PreferredUnitSystem.imperial),
        96000,
      );
    });

    test('set length moves the next line start and preserves closure', () {
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );

      final updated = PlasterGeometry.setLength(lines, 0, 45000);

      expect(updated[0].length, 45000);
      expect(updated[1].startX, 45000);
      expect(updated[1].startY, 0);
      expect(PlasterGeometry.lineEnd(updated, 3).x, updated[0].startX);
      expect(PlasterGeometry.lineEnd(updated, 3).y, updated[0].startY);
    });

    test('ensure line length extends ring for an opening width', () {
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );

      final updated = PlasterGeometry.ensureLineLength(lines, 0, 36000);

      expect(updated[0].length, 36000);
      expect(updated[1].startX, 36000);
    });

    test('split line adds one midpoint segment', () {
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );

      final updated = PlasterGeometry.splitLine(lines, 0);

      expect(updated, hasLength(5));
      expect(updated[0].startX, 0);
      expect(updated[0].startY, 0);
      expect(updated[1].startX, 15000);
      expect(updated[1].startY, 0);
    });

    test('formats and parses display lengths for both unit systems', () {
      expect(
        PlasterGeometry.formatDisplayLength(24000, PreferredUnitSystem.metric),
        '2400 mm',
      );
      expect(
        PlasterGeometry.parseDisplayLength('2400', PreferredUnitSystem.metric),
        24000,
      );
      expect(
        PlasterGeometry.formatDisplayLength(
          30000,
          PreferredUnitSystem.imperial,
        ),
        '2\' 6"',
      );
      expect(
        PlasterGeometry.parseDisplayLength(
          '2\' 6"',
          PreferredUnitSystem.imperial,
        ),
        30000,
      );
    });

    test('convert room bundle converts room, lines and openings', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Room 1',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
      );
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      lines[0].id = 10;
      final opening = PlasterRoomOpening.forInsert(
        lineId: 10,
        type: PlasterOpeningType.window,
        offsetFromStart: 5000,
        width: 12000,
        height: 12000,
        sillHeight: 9000,
      );

      final converted = PlasterGeometry.convertRoomBundle(
        room: room,
        lines: lines,
        openings: [opening],
        target: PreferredUnitSystem.imperial,
      );

      expect(converted.$1.unitSystem, PreferredUnitSystem.imperial);
      expect(converted.$1.ceilingHeight, closeTo(94488, 2));
      expect(converted.$2[1].startX, closeTo(118110, 2));
      expect(converted.$3.first.width, closeTo(47244, 2));
      expect(converted.$3.first.lineId, 10);
    });

    test('calculate layout skips unselected walls and ceiling', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Room 1',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
        plasterCeiling: false,
      );
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      lines[1] = lines[1].copyWith(plasterSelected: false);
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '1200 x 2400',
          unitSystem: PreferredUnitSystem.metric,
          width: 12000,
          height: 24000,
        ),
      ];

      final layouts = PlasterGeometry.calculateLayout([
        PlasterRoomShape(room: room, lines: lines, openings: const []),
      ], materials);

      expect(layouts.length, 3);
      expect(layouts.every((layout) => layout.label.contains('wall')), isTrue);
    });

    test('calculate layout skips rooms with no lines', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Empty Room',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
      );
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '1200 x 2400',
          unitSystem: PreferredUnitSystem.metric,
          width: 12000,
          height: 24000,
        ),
      ];

      final layouts = PlasterGeometry.calculateLayout([
        PlasterRoomShape(room: room, lines: const [], openings: const []),
      ], materials);

      expect(layouts, isEmpty);
    });

    test('horizontal wall layouts use a half-height starter course', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Horizontal Wall',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
        plasterCeiling: false,
      );
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      final selectedWallOnly = [
        lines[0].copyWith(sheetDirection: PlasterSheetDirection.horizontal),
        lines[1].copyWith(plasterSelected: false),
        lines[2].copyWith(plasterSelected: false),
        lines[3].copyWith(plasterSelected: false),
      ];
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '6000 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 60000,
          height: 12000,
        ),
      ];

      final layouts = PlasterGeometry.calculateLayout([
        PlasterRoomShape(
          room: room,
          lines: selectedWallOnly,
          openings: const [],
        ),
      ], materials);

      expect(layouts, hasLength(1));
      expect(layouts.single.direction, PlasterSheetDirection.horizontal);

      final bottomCourse = layouts.single.placements
          .where((placement) => placement.y == 0)
          .toList();
      expect(bottomCourse, isNotEmpty);
      expect(
        bottomCourse.every((placement) => placement.height == 6000),
        isTrue,
      );
    });

    test('auto wall layouts prefer landscape over portrait when valid', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Auto Wall',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
        plasterCeiling: false,
      );
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      final selectedWallOnly = [
        lines[0],
        lines[1].copyWith(plasterSelected: false),
        lines[2].copyWith(plasterSelected: false),
        lines[3].copyWith(plasterSelected: false),
      ];
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '2400 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 24000,
          height: 12000,
        ),
      ];

      final layouts = PlasterGeometry.calculateLayout([
        PlasterRoomShape(
          room: room,
          lines: selectedWallOnly,
          openings: const [],
        ),
      ], materials);

      expect(layouts, hasLength(1));
      expect(layouts.single.direction, PlasterSheetDirection.horizontal);
    });

    test('horizontal layouts keep partial pieces at row ends', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Row Ends',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
        plasterCeiling: false,
      );
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      final selectedWallOnly = [
        lines[0].copyWith(
          length: 15000,
          sheetDirection: PlasterSheetDirection.horizontal,
        ),
        lines[1].copyWith(plasterSelected: false),
        lines[2].copyWith(plasterSelected: false),
        lines[3].copyWith(plasterSelected: false),
      ];
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '6000 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 60000,
          height: 12000,
        ),
      ];

      final layout = PlasterGeometry.calculateLayout([
        PlasterRoomShape(
          room: room,
          lines: selectedWallOnly,
          openings: const [],
        ),
      ], materials).single;

      final rows = <int, List<PlasterSheetPlacement>>{};
      for (final placement in layout.placements) {
        rows.putIfAbsent(placement.y, () => []).add(placement);
      }

      for (final row in rows.values) {
        row.sort((left, right) => left.x.compareTo(right.x));
        final partialIndexes = <int>[
          for (var i = 0; i < row.length; i++)
            if (row[i].width != 60000) i,
        ];
        expect(partialIndexes.length, lessThanOrEqualTo(2));
        expect(
          partialIndexes.every(
            (index) => index == 0 || index == row.length - 1,
          ),
          isTrue,
        );
      }
    });

    test('adjacent rows stagger joints by at least 300mm', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Stagger',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
        plasterCeiling: false,
      );
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      final selectedWallOnly = [
        lines[0].copyWith(
          length: 15000,
          sheetDirection: PlasterSheetDirection.horizontal,
        ),
        lines[1].copyWith(plasterSelected: false),
        lines[2].copyWith(plasterSelected: false),
        lines[3].copyWith(plasterSelected: false),
      ];
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '6000 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 60000,
          height: 12000,
        ),
      ];

      final layout = PlasterGeometry.calculateLayout([
        PlasterRoomShape(
          room: room,
          lines: selectedWallOnly,
          openings: const [],
        ),
      ], materials).single;

      final rows = <int, List<PlasterSheetPlacement>>{};
      for (final placement in layout.placements) {
        rows.putIfAbsent(placement.y, () => []).add(placement);
      }
      final sortedRows = rows.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key));

      List<int> jointsFor(List<PlasterSheetPlacement> row) {
        row.sort((left, right) => left.x.compareTo(right.x));
        final joints = <int>[];
        var position = 0;
        for (var i = 0; i < row.length - 1; i++) {
          position += row[i].width;
          joints.add(position);
        }
        return joints;
      }

      for (var i = 1; i < sortedRows.length; i++) {
        final previousJoints = jointsFor(sortedRows[i - 1].value);
        final currentJoints = jointsFor(sortedRows[i].value);
        for (final previous in previousJoints) {
          for (final current in currentJoints) {
            expect((previous - current).abs(), greaterThanOrEqualTo(3000));
          }
        }
      }
    });

    test('horizontal wall joints align to studs from project defaults', () {
      final project = PlasterProject.forInsert(
        name: 'Studs',
        jobId: 1,
        wastePercent: 15,
        wallStudSpacing: 3000,
      );
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Stud Wall',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
        plasterCeiling: false,
      );
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      final selectedWallOnly = [
        lines[0].copyWith(
          length: 210000,
          sheetDirection: PlasterSheetDirection.horizontal,
        ),
        lines[1].copyWith(plasterSelected: false),
        lines[2].copyWith(plasterSelected: false),
        lines[3].copyWith(plasterSelected: false),
      ];
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '6000 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 60000,
          height: 12000,
        ),
      ];

      final layout = PlasterGeometry.calculateLayout([
        PlasterRoomShape(
          project: project,
          room: room,
          lines: selectedWallOnly,
          openings: const [],
        ),
      ], materials).single;

      final rows = <int, List<PlasterSheetPlacement>>{};
      for (final placement in layout.placements) {
        rows.putIfAbsent(placement.y, () => []).add(placement);
      }
      final studPositions = {for (var x = 0; x <= 210000; x += 3000) x};

      for (final row in rows.values) {
        row.sort((left, right) => left.x.compareTo(right.x));
        for (var i = 0; i < row.length - 1; i++) {
          expect(studPositions.contains(row[i].x + row[i].width), isTrue);
        }
      }
    });

    test('per-wall stud override avoids repeated butt joints', () {
      final project = PlasterProject.forInsert(
        name: 'Stud Override',
        jobId: 1,
        wastePercent: 15,
        wallStudSpacing: 4500,
      );
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Override Wall',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
        plasterCeiling: false,
      );
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      final selectedWallOnly = [
        lines[0].copyWith(
          length: 210000,
          sheetDirection: PlasterSheetDirection.horizontal,
          studSpacingOverride: 3000,
        ),
        lines[1].copyWith(plasterSelected: false),
        lines[2].copyWith(plasterSelected: false),
        lines[3].copyWith(plasterSelected: false),
      ];
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '6000 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 60000,
          height: 12000,
        ),
      ];

      final layout = PlasterGeometry.calculateLayout([
        PlasterRoomShape(
          project: project,
          room: room,
          lines: selectedWallOnly,
          openings: const [],
        ),
      ], materials).single;

      final rows = <int, List<PlasterSheetPlacement>>{};
      for (final placement in layout.placements) {
        rows.putIfAbsent(placement.y, () => []).add(placement);
      }
      final sortedRows = rows.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key));

      List<int> jointsFor(List<PlasterSheetPlacement> row) {
        row.sort((left, right) => left.x.compareTo(right.x));
        return [
          for (var i = 0; i < row.length - 1; i++) row[i].x + row[i].width,
        ];
      }

      expect(sortedRows.length, greaterThan(1));
      expect(
        jointsFor(sortedRows.first.value),
        isNot(equals(jointsFor(sortedRows[1].value))),
      );
    });

    test('ceiling layout rebalances remainder to avoid thin edge strips', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Ceiling Rebalance',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
      );
      final lines = [
        PlasterRoomLine.forInsert(
          roomId: 1,
          seqNo: 0,
          startX: 0,
          startY: 0,
          length: 46620,
          plasterSelected: false,
        ),
        PlasterRoomLine.forInsert(
          roomId: 1,
          seqNo: 1,
          startX: 46620,
          startY: 0,
          length: 25000,
          plasterSelected: false,
        ),
        PlasterRoomLine.forInsert(
          roomId: 1,
          seqNo: 2,
          startX: 46620,
          startY: 25000,
          length: 46620,
          plasterSelected: false,
        ),
        PlasterRoomLine.forInsert(
          roomId: 1,
          seqNo: 3,
          startX: 0,
          startY: 25000,
          length: 25000,
          plasterSelected: false,
        ),
      ];
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '1200 x 3000',
          unitSystem: PreferredUnitSystem.metric,
          width: 12000,
          height: 30000,
        ),
      ];

      final layout = PlasterGeometry.calculateLayout([
        PlasterRoomShape(room: room, lines: lines, openings: const []),
      ], materials).single;

      final rowHeights =
          layout.placements
              .map((placement) => placement.height)
              .toSet()
              .toList()
            ..sort();

      expect(rowHeights, containsAll([6500, 12000]));
      expect(rowHeights, isNot(contains(3000)));
      expect(rowHeights.every((height) => height >= 6000), isTrue);
    });

    test('calculate takeoff includes sheet totals and wastage', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Room 1',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
      );
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '1200 x 2400',
          unitSystem: PreferredUnitSystem.metric,
          width: 12000,
          height: 24000,
        ),
      ];
      final shape = PlasterRoomShape(
        room: room,
        lines: lines,
        openings: const [],
      );

      final layouts = PlasterGeometry.calculateLayout([shape], materials);
      final takeoff = PlasterGeometry.calculateTakeoff([shape], layouts, 15);

      expect(takeoff.totalSheetCount, greaterThan(0));
      expect(
        takeoff.totalSheetCountWithWaste,
        greaterThanOrEqualTo(takeoff.totalSheetCount),
      );
      expect(
        takeoff.totalSheetCountWithWaste,
        equals((takeoff.totalSheetCount * 1.15).ceil()),
      );
      expect(takeoff.estimatedWasteArea, greaterThanOrEqualTo(0));
      expect(takeoff.estimatedWastePercent, greaterThanOrEqualTo(0));
    });

    test('project takeoff does not exceed summed raw layout sheets', () {
      final room1 = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Room 1',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 12000,
        plasterCeiling: false,
      );
      final room2 = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Room 2',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 12000,
        plasterCeiling: false,
      );
      final lines1 = [
        ...PlasterGeometry.defaultLines(
          roomId: 1,
          unitSystem: PreferredUnitSystem.metric,
        ),
      ];
      final lines2 = [
        ...PlasterGeometry.defaultLines(
          roomId: 2,
          unitSystem: PreferredUnitSystem.metric,
        ),
      ];
      for (var i = 1; i < 4; i++) {
        lines1[i] = lines1[i].copyWith(plasterSelected: false);
        lines2[i] = lines2[i].copyWith(plasterSelected: false);
      }
      lines1[0] = lines1[0].copyWith(length: 30000);
      lines2[0] = lines2[0].copyWith(length: 30000);
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '6000 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 60000,
          height: 12000,
        ),
      ];
      final shapes = [
        PlasterRoomShape(room: room1, lines: lines1, openings: const []),
        PlasterRoomShape(room: room2, lines: lines2, openings: const []),
      ];

      final layouts = PlasterGeometry.calculateLayout(shapes, materials);
      final takeoff = PlasterGeometry.calculateTakeoff(shapes, layouts, 0);

      expect(layouts, hasLength(2));
      final rawSheetCount = layouts.fold<int>(
        0,
        (sum, layout) => sum + layout.sheetCount,
      );
      expect(takeoff.totalSheetCount, lessThanOrEqualTo(rawSheetCount));
    });

    test('vertical wall layout is rejected by the generator', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Room 1',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
        plasterCeiling: false,
      );
      final lines = [
        ...PlasterGeometry.defaultLines(
          roomId: 1,
          unitSystem: PreferredUnitSystem.metric,
        ),
      ];
      for (var i = 1; i < 4; i++) {
        lines[i] = lines[i].copyWith(plasterSelected: false);
      }
      lines[0] = lines[0].copyWith(
        sheetDirection: PlasterSheetDirection.vertical,
      );
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '1800 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 18000,
          height: 12000,
        ),
      ];

      final layouts = PlasterGeometry.calculateLayout([
        PlasterRoomShape(room: room, lines: lines, openings: const []),
      ], materials);

      expect(layouts, isEmpty);
    });

    test('estimated waste excludes contingency sheets', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Waste',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
      );
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      final shape = PlasterRoomShape(
        room: room,
        lines: lines,
        openings: const [],
      );
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '6000 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 60000,
          height: 12000,
        ),
      ];
      final layouts = PlasterGeometry.calculateLayout([shape], materials);

      final rawTakeoff = PlasterGeometry.calculateTakeoff([shape], layouts, 0);
      final wasteTakeoff = PlasterGeometry.calculateTakeoff(
        [shape],
        layouts,
        15,
      );

      expect(
        wasteTakeoff.estimatedWasteArea,
        equals(rawTakeoff.estimatedWasteArea),
      );
      expect(
        wasteTakeoff.totalSheetCountWithWaste,
        greaterThanOrEqualTo(rawTakeoff.totalSheetCount),
      );
    });
  });
}
