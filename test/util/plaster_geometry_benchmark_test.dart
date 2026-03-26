import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';

class _BenchmarkCase {
  final String name;
  final int width;
  final int depth;
  final int ceilingHeight;
  final bool plasterCeiling;
  final int maxSheets;
  final double maxWastePercent;

  const _BenchmarkCase({
    required this.name,
    required this.width,
    required this.depth,
    required this.ceilingHeight,
    required this.plasterCeiling,
    required this.maxSheets,
    required this.maxWastePercent,
  });
}

void main() {
  group('PlasterGeometry benchmark layouts', () {
    const cases = <_BenchmarkCase>[
      _BenchmarkCase(
        name: '3.0m x 3.0m walls only',
        width: 30000,
        depth: 30000,
        ceilingHeight: 24000,
        plasterCeiling: false,
        maxSheets: 4,
        maxWastePercent: 5,
      ),
      _BenchmarkCase(
        name: '3.0m x 3.0m with ceiling',
        width: 30000,
        depth: 30000,
        ceilingHeight: 24000,
        plasterCeiling: true,
        maxSheets: 6,
        maxWastePercent: 15,
      ),
      _BenchmarkCase(
        name: '4.2m x 3.6m bedroom with ceiling',
        width: 42000,
        depth: 36000,
        ceilingHeight: 24000,
        plasterCeiling: true,
        maxSheets: 9,
        maxWastePercent: 30,
      ),
      _BenchmarkCase(
        name: '5.4m x 3.6m living room walls only',
        width: 54000,
        depth: 36000,
        ceilingHeight: 24000,
        plasterCeiling: false,
        maxSheets: 7,
        maxWastePercent: 15,
      ),
    ];

    final materials = [
      PlasterMaterialSize.forInsert(
        supplierId: 1,
        name: '3600 x 1200',
        unitSystem: PreferredUnitSystem.metric,
        width: 36000,
        height: 12000,
      ),
      PlasterMaterialSize.forInsert(
        supplierId: 1,
        name: '4800 x 1200',
        unitSystem: PreferredUnitSystem.metric,
        width: 48000,
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

    test('common room scenarios stay within benchmark thresholds', () {
      for (var index = 0; index < cases.length; index++) {
        final scenario = cases[index];
        final shape = _rectangleShape(
          roomId: index + 1,
          projectId: 1,
          name: scenario.name,
          width: scenario.width,
          depth: scenario.depth,
          ceilingHeight: scenario.ceilingHeight,
          plasterCeiling: scenario.plasterCeiling,
        );

        final layouts = PlasterGeometry.calculateLayout([shape], materials);
        final takeoff = PlasterGeometry.calculateTakeoff([shape], layouts, 0);

        expect(
          takeoff.totalSheetCount,
          lessThanOrEqualTo(scenario.maxSheets),
          reason:
              '${scenario.name}: expected <= ${scenario.maxSheets} sheets, '
              'got ${takeoff.totalSheetCount}',
        );
        expect(
          takeoff.estimatedWastePercent,
          lessThanOrEqualTo(scenario.maxWastePercent),
          reason:
              '${scenario.name}: expected <= '
              '${scenario.maxWastePercent.toStringAsFixed(1)}% waste, got '
              '${takeoff.estimatedWastePercent.toStringAsFixed(1)}%',
        );
      }
    });
  });
}

PlasterRoomShape _rectangleShape({
  required int roomId,
  required int projectId,
  required String name,
  required int width,
  required int depth,
  required int ceilingHeight,
  required bool plasterCeiling,
}) {
  final room = PlasterRoom.forInsert(
    projectId: projectId,
    name: name,
    unitSystem: PreferredUnitSystem.metric,
    ceilingHeight: ceilingHeight,
    plasterCeiling: plasterCeiling,
  );
  var lines = PlasterGeometry.defaultLines(
    roomId: roomId,
    unitSystem: PreferredUnitSystem.metric,
  );
  lines = PlasterGeometry.setLength(lines, 0, width);
  lines = PlasterGeometry.setLength(lines, 1, depth);
  lines = PlasterGeometry.setLength(lines, 2, width);
  lines = PlasterGeometry.setLength(lines, 3, depth);

  return PlasterRoomShape(
    room: room,
    lines: lines,
    openings: const [],
  );
}
