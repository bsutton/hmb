import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';

class _BenchmarkCase {
  final String name;
  final List<PlasterRoomShape> Function() buildShapes;
  final int maxSheets;
  final double maxWastePercent;
  final int maxJointTapeLength;

  const _BenchmarkCase({
    required this.name,
    required this.buildShapes,
    required this.maxSheets,
    required this.maxWastePercent,
    required this.maxJointTapeLength,
  });
}

class _BenchmarkMetrics {
  final int totalSheetCount;
  final double wastePercent;
  final int jointTapeLength;

  const _BenchmarkMetrics({
    required this.totalSheetCount,
    required this.wastePercent,
    required this.jointTapeLength,
  });
}

void main() {
  group('PlasterGeometry benchmark layouts', () {
    // These cases are baseline regression checks for solver quality.
    // They are not golden-optimal targets yet, but they define a stable corpus
    // we can compare against as the solver evolves.
    final materials = [
      PlasterMaterialSize.forInsert(
        supplierId: 1,
        name: '2400 x 1200',
        unitSystem: PreferredUnitSystem.metric,
        width: 24000,
        height: 12000,
      ),
      PlasterMaterialSize.forInsert(
        supplierId: 1,
        name: '2700 x 1200',
        unitSystem: PreferredUnitSystem.metric,
        width: 27000,
        height: 12000,
      ),
      PlasterMaterialSize.forInsert(
        supplierId: 1,
        name: '3000 x 1200',
        unitSystem: PreferredUnitSystem.metric,
        width: 30000,
        height: 12000,
      ),
      PlasterMaterialSize.forInsert(
        supplierId: 1,
        name: '3600 x 1200',
        unitSystem: PreferredUnitSystem.metric,
        width: 36000,
        height: 12000,
      ),
      PlasterMaterialSize.forInsert(
        supplierId: 1,
        name: '4200 x 1200',
        unitSystem: PreferredUnitSystem.metric,
        width: 42000,
        height: 12000,
      ),
    ];

    final cases = <_BenchmarkCase>[
      _BenchmarkCase(
        name: '3.0m x 3.0m walls only',
        buildShapes: () => [
          _rectangleShape(
            roomId: 1,
            projectId: 1,
            name: '3.0m x 3.0m walls only',
            width: 30000,
            depth: 30000,
            ceilingHeight: 24000,
            plasterCeiling: false,
          ),
        ],
        maxSheets: 12,
        maxWastePercent: 150,
        maxJointTapeLength: 260000,
      ),
      _BenchmarkCase(
        name: '3.0m x 3.0m with ceiling',
        buildShapes: () => [
          _rectangleShape(
            roomId: 2,
            projectId: 1,
            name: '3.0m x 3.0m with ceiling',
            width: 30000,
            depth: 30000,
            ceilingHeight: 24000,
            plasterCeiling: true,
          ),
        ],
        maxSheets: 15,
        maxWastePercent: 150,
        maxJointTapeLength: 350000,
      ),
      _BenchmarkCase(
        name: '4.2m x 3.6m bedroom with ceiling',
        buildShapes: () => [
          _rectangleShape(
            roomId: 3,
            projectId: 1,
            name: '4.2m x 3.6m bedroom with ceiling',
            width: 42000,
            depth: 36000,
            ceilingHeight: 24000,
            plasterCeiling: true,
          ),
        ],
        maxSheets: 26,
        maxWastePercent: 150,
        maxJointTapeLength: 550000,
      ),
      _BenchmarkCase(
        name: '5.4m x 3.6m living room walls only',
        buildShapes: () => [
          _rectangleShape(
            roomId: 4,
            projectId: 1,
            name: '5.4m x 3.6m living room walls only',
            width: 54000,
            depth: 36000,
            ceilingHeight: 24000,
            plasterCeiling: false,
          ),
        ],
        maxSheets: 16,
        maxWastePercent: 150,
        maxJointTapeLength: 450000,
      ),
      _BenchmarkCase(
        name: '7.2m x 3.0m hallway with ceiling',
        buildShapes: () => [
          _rectangleShape(
            roomId: 5,
            projectId: 1,
            name: '7.2m x 3.0m hallway with ceiling',
            width: 72000,
            depth: 30000,
            ceilingHeight: 24000,
            plasterCeiling: true,
          ),
        ],
        maxSheets: 28,
        maxWastePercent: 170,
        maxJointTapeLength: 750000,
      ),
      _BenchmarkCase(
        name: '6.0m x 5.4m large open room with ceiling',
        buildShapes: () => [
          _rectangleShape(
            roomId: 6,
            projectId: 1,
            name: '6.0m x 5.4m large open room with ceiling',
            width: 60000,
            depth: 54000,
            ceilingHeight: 27000,
            plasterCeiling: true,
          ),
        ],
        maxSheets: 40,
        maxWastePercent: 180,
        maxJointTapeLength: 950000,
      ),
      _BenchmarkCase(
        name: 'notched family room with ceiling',
        buildShapes: () => [
          _polygonShape(
            roomId: 7,
            projectId: 1,
            name: 'notched family room with ceiling',
            ceilingHeight: 24000,
            plasterCeiling: true,
            points: const [
              IntPoint(0, 0),
              IntPoint(54000, 0),
              IntPoint(54000, 24000),
              IntPoint(36000, 24000),
              IntPoint(36000, 42000),
              IntPoint(0, 42000),
            ],
          ),
        ],
        maxSheets: 34,
        maxWastePercent: 180,
        maxJointTapeLength: 850000,
      ),
    ];

    test('baseline room corpus stays within benchmark thresholds', () {
      for (final scenario in cases) {
        final shapes = scenario.buildShapes();
        final layouts = PlasterGeometry.calculateLayout(shapes, materials);
        final takeoff = PlasterGeometry.calculateTakeoff(shapes, layouts, 0);
        final metrics = _BenchmarkMetrics(
          totalSheetCount: takeoff.totalSheetCount,
          wastePercent: takeoff.estimatedWastePercent,
          jointTapeLength: layouts.fold<int>(
            0,
            (sum, layout) => sum + layout.estimatedJointTapeLength,
          ),
        );

        expect(
          metrics.totalSheetCount,
          lessThanOrEqualTo(scenario.maxSheets),
          reason:
              '${scenario.name}: expected <= ${scenario.maxSheets} sheets, '
              'got ${metrics.totalSheetCount}',
        );
        expect(
          metrics.wastePercent,
          lessThanOrEqualTo(scenario.maxWastePercent),
          reason:
              '${scenario.name}: expected <= '
              '${scenario.maxWastePercent.toStringAsFixed(1)}% waste, got '
              '${metrics.wastePercent.toStringAsFixed(1)}%',
        );
        expect(
          metrics.jointTapeLength,
          lessThanOrEqualTo(scenario.maxJointTapeLength),
          reason:
              '${scenario.name}: expected <= ${scenario.maxJointTapeLength} '
              'joint-tape units, got ${metrics.jointTapeLength}',
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

  return PlasterRoomShape(room: room, lines: lines, openings: const []);
}

PlasterRoomShape _polygonShape({
  required int roomId,
  required int projectId,
  required String name,
  required int ceilingHeight,
  required bool plasterCeiling,
  required List<IntPoint> points,
}) {
  final room = PlasterRoom.forInsert(
    projectId: projectId,
    name: name,
    unitSystem: PreferredUnitSystem.metric,
    ceilingHeight: ceilingHeight,
    plasterCeiling: plasterCeiling,
  );
  final lines = <PlasterRoomLine>[];
  for (var i = 0; i < points.length; i++) {
    final start = points[i];
    final end = points[(i + 1) % points.length];
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    lines.add(
      PlasterRoomLine.forInsert(
        roomId: roomId,
        seqNo: i,
        startX: start.x,
        startY: start.y,
        length: sqrt(dx * dx + dy * dy).round(),
      )..id = i + 1,
    );
  }

  return PlasterRoomShape(room: room, lines: lines, openings: const []);
}
