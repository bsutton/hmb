import 'package:hmb/util/dart/plaster_geometry.dart';

class SolverBenchmarkFixtureSetV1 {
  final int schemaVersion;
  final String scoringVersion;
  final List<SolverBenchmarkScenarioV1> scenarios;

  const SolverBenchmarkFixtureSetV1({
    required this.schemaVersion,
    required this.scoringVersion,
    required this.scenarios,
  });
}

class SolverBenchmarkScenarioV1 {
  final String id;
  final String name;
  final List<SolverBenchmarkRoomV1> rooms;

  const SolverBenchmarkScenarioV1({
    required this.id,
    required this.name,
    required this.rooms,
  });
}

class SolverBenchmarkRoomV1 {
  final int roomId;
  final int projectId;
  final String name;
  final int ceilingHeight;
  final bool plasterCeiling;
  final List<IntPoint> points;

  const SolverBenchmarkRoomV1({
    required this.roomId,
    required this.projectId,
    required this.name,
    required this.ceilingHeight,
    required this.plasterCeiling,
    required this.points,
  });
}

const plasterSolverBenchmarkFixtureSetV1 = SolverBenchmarkFixtureSetV1(
  schemaVersion: 1,
  scoringVersion: 'v1',
  scenarios: [
    SolverBenchmarkScenarioV1(
      id: 'square_3x3_walls_only',
      name: '3.0m x 3.0m walls only',
      rooms: [
        SolverBenchmarkRoomV1(
          roomId: 1,
          projectId: 1,
          name: '3.0m x 3.0m walls only',
          ceilingHeight: 24000,
          plasterCeiling: false,
          points: [
            IntPoint(0, 0),
            IntPoint(30000, 0),
            IntPoint(30000, 30000),
            IntPoint(0, 30000),
          ],
        ),
      ],
    ),
    SolverBenchmarkScenarioV1(
      id: 'square_3x3_with_ceiling',
      name: '3.0m x 3.0m with ceiling',
      rooms: [
        SolverBenchmarkRoomV1(
          roomId: 2,
          projectId: 1,
          name: '3.0m x 3.0m with ceiling',
          ceilingHeight: 24000,
          plasterCeiling: true,
          points: [
            IntPoint(0, 0),
            IntPoint(30000, 0),
            IntPoint(30000, 30000),
            IntPoint(0, 30000),
          ],
        ),
      ],
    ),
    SolverBenchmarkScenarioV1(
      id: 'bedroom_4_2x3_6_with_ceiling',
      name: '4.2m x 3.6m bedroom with ceiling',
      rooms: [
        SolverBenchmarkRoomV1(
          roomId: 3,
          projectId: 1,
          name: '4.2m x 3.6m bedroom with ceiling',
          ceilingHeight: 24000,
          plasterCeiling: true,
          points: [
            IntPoint(0, 0),
            IntPoint(42000, 0),
            IntPoint(42000, 36000),
            IntPoint(0, 36000),
          ],
        ),
      ],
    ),
    SolverBenchmarkScenarioV1(
      id: 'living_5_4x3_6_walls_only',
      name: '5.4m x 3.6m living room walls only',
      rooms: [
        SolverBenchmarkRoomV1(
          roomId: 4,
          projectId: 1,
          name: '5.4m x 3.6m living room walls only',
          ceilingHeight: 24000,
          plasterCeiling: false,
          points: [
            IntPoint(0, 0),
            IntPoint(54000, 0),
            IntPoint(54000, 36000),
            IntPoint(0, 36000),
          ],
        ),
      ],
    ),
    SolverBenchmarkScenarioV1(
      id: 'hallway_7_2x3_0_with_ceiling',
      name: '7.2m x 3.0m hallway with ceiling',
      rooms: [
        SolverBenchmarkRoomV1(
          roomId: 5,
          projectId: 1,
          name: '7.2m x 3.0m hallway with ceiling',
          ceilingHeight: 24000,
          plasterCeiling: true,
          points: [
            IntPoint(0, 0),
            IntPoint(72000, 0),
            IntPoint(72000, 30000),
            IntPoint(0, 30000),
          ],
        ),
      ],
    ),
    SolverBenchmarkScenarioV1(
      id: 'open_room_6_0x5_4_with_ceiling',
      name: '6.0m x 5.4m large open room with ceiling',
      rooms: [
        SolverBenchmarkRoomV1(
          roomId: 6,
          projectId: 1,
          name: '6.0m x 5.4m large open room with ceiling',
          ceilingHeight: 27000,
          plasterCeiling: true,
          points: [
            IntPoint(0, 0),
            IntPoint(60000, 0),
            IntPoint(60000, 54000),
            IntPoint(0, 54000),
          ],
        ),
      ],
    ),
    SolverBenchmarkScenarioV1(
      id: 'notched_family_room_with_ceiling',
      name: 'notched family room with ceiling',
      rooms: [
        SolverBenchmarkRoomV1(
          roomId: 7,
          projectId: 1,
          name: 'notched family room with ceiling',
          ceilingHeight: 24000,
          plasterCeiling: true,
          points: [
            IntPoint(0, 0),
            IntPoint(54000, 0),
            IntPoint(54000, 24000),
            IntPoint(36000, 24000),
            IntPoint(36000, 42000),
            IntPoint(0, 42000),
          ],
        ),
      ],
    ),
    SolverBenchmarkScenarioV1(
      id: 'large_ceiling_13_184x5_413',
      name: '13.184m x 5.413m ceiling stress case',
      rooms: [
        SolverBenchmarkRoomV1(
          roomId: 8,
          projectId: 1,
          name: '13.184m x 5.413m ceiling stress case',
          ceilingHeight: 24000,
          plasterCeiling: true,
          points: [
            IntPoint(0, 0),
            IntPoint(131840, 0),
            IntPoint(131840, 54130),
            IntPoint(0, 54130),
          ],
        ),
      ],
    ),
  ],
);
