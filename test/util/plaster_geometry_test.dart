import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';

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
          projectId: 1,
          name: '1200 x 2400',
          unitSystem: PreferredUnitSystem.metric,
          width: 12000,
          height: 24000,
        ),
      ];

      final layouts = PlasterGeometry.calculateLayout(
        [PlasterRoomShape(room: room, lines: lines, openings: const [])],
        materials,
        15,
      );

      expect(layouts.length, 3);
      expect(layouts.every((layout) => layout.label.contains('wall')), isTrue);
    });
  });
}
