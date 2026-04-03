import 'dart:math';

import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';

import '../fixtures/plaster_solver/v1/baseline_results_v1.dart';
import '../fixtures/plaster_solver/v1/benchmark_fixture_v1.dart';

class SolverBenchmarkScenario {
  final String id;
  final String name;
  final List<PlasterRoomShape> shapes;

  const SolverBenchmarkScenario({
    required this.id,
    required this.name,
    required this.shapes,
  });
}

class SolverBenchmarkBaseline {
  final String scenarioId;
  final int maxSheets;
  final double maxWastePercent;
  final int maxJointTapeLength;

  const SolverBenchmarkBaseline({
    required this.scenarioId,
    required this.maxSheets,
    required this.maxWastePercent,
    required this.maxJointTapeLength,
  });
}

class SolverBenchmarkCorpus {
  final int schemaVersion;
  final String scoringVersion;
  final List<SolverBenchmarkScenario> scenarios;
  final Map<String, SolverBenchmarkBaseline> baselinesByScenarioId;

  const SolverBenchmarkCorpus({
    required this.schemaVersion,
    required this.scoringVersion,
    required this.scenarios,
    required this.baselinesByScenarioId,
  });
}

class SolverBenchmarkMetrics {
  final int totalSheetCount;
  final double wastePercent;
  final int jointTapeLength;

  const SolverBenchmarkMetrics({
    required this.totalSheetCount,
    required this.wastePercent,
    required this.jointTapeLength,
  });
}

SolverBenchmarkCorpus loadPlasterSolverBenchmarkCorpus() {
  const fixtures = plasterSolverBenchmarkFixtureSetV1;
  const baselines = plasterSolverBaselineResultsV1;

  if (fixtures.schemaVersion != baselines.schemaVersion) {
    throw StateError(
      'Fixture schema version ${fixtures.schemaVersion} does not match '
      'baseline schema version ${baselines.schemaVersion}.',
    );
  }
  if (fixtures.scoringVersion != baselines.scoringVersion) {
    throw StateError(
      'Fixture scoring version ${fixtures.scoringVersion} does not match '
      'baseline scoring version ${baselines.scoringVersion}.',
    );
  }

  return SolverBenchmarkCorpus(
    schemaVersion: fixtures.schemaVersion,
    scoringVersion: fixtures.scoringVersion,
    scenarios: [
      for (final scenario in fixtures.scenarios)
        SolverBenchmarkScenario(
          id: scenario.id,
          name: scenario.name,
          shapes: [for (final room in scenario.rooms) _roomToShape(room)],
        ),
    ],
    baselinesByScenarioId: {
      for (final baseline in baselines.baselines)
        baseline.scenarioId: SolverBenchmarkBaseline(
          scenarioId: baseline.scenarioId,
          maxSheets: baseline.maxSheets,
          maxWastePercent: baseline.maxWastePercent,
          maxJointTapeLength: baseline.maxJointTapeLength,
        ),
    },
  );
}

SolverBenchmarkMetrics calculateSolverBenchmarkMetrics(
  List<PlasterRoomShape> shapes,
  List<PlasterMaterialSize> materials,
) {
  final layouts = PlasterGeometry.calculateLayout(shapes, materials);
  final takeoff = PlasterGeometry.calculateTakeoff(shapes, layouts, 0);
  return SolverBenchmarkMetrics(
    totalSheetCount: takeoff.totalSheetCount,
    wastePercent: takeoff.estimatedWastePercent,
    jointTapeLength: layouts.fold<int>(
      0,
      (sum, layout) => sum + layout.estimatedJointTapeLength,
    ),
  );
}

PlasterRoomShape _roomToShape(SolverBenchmarkRoomV1 room) {
  final entity = PlasterRoom.forInsert(
    projectId: room.projectId,
    name: room.name,
    unitSystem: PreferredUnitSystem.metric,
    ceilingHeight: room.ceilingHeight,
    plasterCeiling: room.plasterCeiling,
  );
  final lines = <PlasterRoomLine>[];
  for (var i = 0; i < room.points.length; i++) {
    final start = room.points[i];
    final end = room.points[(i + 1) % room.points.length];
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    lines.add(
      PlasterRoomLine.forInsert(
        roomId: room.roomId,
        seqNo: i,
        startX: start.x,
        startY: start.y,
        length: sqrt(dx * dx + dy * dy).round(),
      )..id = i + 1,
    );
  }
  return PlasterRoomShape(room: entity, lines: lines, openings: const []);
}
