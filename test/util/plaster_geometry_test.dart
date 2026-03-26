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

      final layouts = PlasterGeometry.calculateLayout(
        [PlasterRoomShape(room: room, lines: lines, openings: const [])],
        materials,
      );

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

      final layouts = PlasterGeometry.calculateLayout(
        [PlasterRoomShape(room: room, lines: const [], openings: const [])],
        materials,
      );

      expect(layouts, isEmpty);
    });

    test(
      'calculate layout reuses offcuts across a wall before adding waste',
      () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Reuse Wall',
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
          name: '6000 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 60000,
          height: 12000,
        ),
      ];

      final layouts = PlasterGeometry.calculateLayout(
        [
          PlasterRoomShape(
            room: room,
            lines: selectedWallOnly,
            openings: const [],
          ),
        ],
        materials,
      );

      expect(layouts.single.sheetCount, 1);
      },
    );

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

    test('calculate takeoff reuses sheets across room surfaces', () {
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
        PlasterRoomShape(
          room: room1,
          lines: lines1,
          openings: const [],
        ),
        PlasterRoomShape(
          room: room2,
          lines: lines2,
          openings: const [],
        ),
      ];

      final layouts = PlasterGeometry.calculateLayout(shapes, materials);
      final takeoff = PlasterGeometry.calculateTakeoff(shapes, layouts, 0);

      expect(layouts, hasLength(2));
      expect(layouts.every((layout) => layout.sheetCount == 1), isTrue);
      expect(takeoff.totalSheetCount, 1);
    });

    test('calculate layout chooses a globally better material combination', () {
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
      final shapes = [
        PlasterRoomShape(
          room: room1,
          lines: lines1,
          openings: const [],
        ),
        PlasterRoomShape(
          room: room2,
          lines: lines2,
          openings: const [],
        ),
      ];
      final materials = [
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '3000 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 30000,
          height: 12000,
        ),
        PlasterMaterialSize.forInsert(
          supplierId: 1,
          name: '6000 x 1200',
          unitSystem: PreferredUnitSystem.metric,
          width: 60000,
          height: 12000,
        ),
      ];

      final layouts = PlasterGeometry.calculateLayout(shapes, materials);
      final takeoff = PlasterGeometry.calculateTakeoff(shapes, layouts, 0);

      expect(layouts, hasLength(2));
      expect(
        layouts.every((layout) => layout.material.name == '6000 x 1200'),
        isTrue,
      );
      expect(takeoff.totalSheetCount, 1);
    });

    test('calculate takeoff rotates and packs project pieces efficiently', () {
      final room = PlasterRoom.forInsert(
        projectId: 1,
        name: 'Packing',
        unitSystem: PreferredUnitSystem.metric,
        ceilingHeight: 24000,
        plasterCeiling: false,
      );
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      for (var i = 2; i < 4; i++) {
        lines[i] = lines[i].copyWith(plasterSelected: false);
      }
      final shape = PlasterRoomShape(
        room: room,
        lines: lines,
        openings: const [],
      );
      final material = PlasterMaterialSize.forInsert(
        supplierId: 1,
        name: '4000 x 3000',
        unitSystem: PreferredUnitSystem.metric,
        width: 40000,
        height: 30000,
      );
      final layouts = [
        PlasterSurfaceLayout(
          roomId: room.id,
          lineId: 1,
          isCeiling: false,
          label: 'A',
          material: material,
          direction: PlasterSheetDirection.horizontal,
          width: 30000,
          height: 12000,
          area: 30000 * 12000,
          sheetsAcross: 1,
          sheetsDown: 1,
          sheetCount: 1,
          sheetCountWithWaste: 1,
          placements: const [
            PlasterSheetPlacement(
              x: 0,
              y: 0,
              width: 30000,
              height: 12000,
            ),
          ],
          estimatedJointTapeLength: 0,
          estimatedScrewCount: 0,
          estimatedGlueKg: 0,
          estimatedPlasterKg: 0,
        ),
        PlasterSurfaceLayout(
          roomId: room.id,
          lineId: 2,
          isCeiling: false,
          label: 'B',
          material: material,
          direction: PlasterSheetDirection.vertical,
          width: 12000,
          height: 30000,
          area: 12000 * 30000,
          sheetsAcross: 1,
          sheetsDown: 1,
          sheetCount: 1,
          sheetCountWithWaste: 1,
          placements: const [
            PlasterSheetPlacement(
              x: 0,
              y: 0,
              width: 12000,
              height: 30000,
            ),
          ],
          estimatedJointTapeLength: 0,
          estimatedScrewCount: 0,
          estimatedGlueKg: 0,
          estimatedPlasterKg: 0,
        ),
      ];

      final takeoff = PlasterGeometry.calculateTakeoff([shape], layouts, 0);

      expect(takeoff.totalSheetCount, 1);
    });
  });
}
