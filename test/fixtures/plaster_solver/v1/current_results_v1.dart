class SolverBenchmarkCurrentResultsV1 {
  final int schemaVersion;
  final String scoringVersion;
  final String solverFamily;
  final List<SolverBenchmarkCurrentResultV1> results;

  const SolverBenchmarkCurrentResultsV1({
    required this.schemaVersion,
    required this.scoringVersion,
    required this.solverFamily,
    required this.results,
  });
}

class SolverBenchmarkCurrentResultV1 {
  final String scenarioId;
  final int totalSheetCount;
  final double wastePercent;
  final int jointTapeLength;

  const SolverBenchmarkCurrentResultV1({
    required this.scenarioId,
    required this.totalSheetCount,
    required this.wastePercent,
    required this.jointTapeLength,
  });
}

const plasterSolverCurrentResultsV1 = SolverBenchmarkCurrentResultsV1(
  schemaVersion: 1,
  scoringVersion: 'v1',
  solverFamily: 'deterministic_layout_v1',
  results: [
    SolverBenchmarkCurrentResultV1(
      scenarioId: 'square_3x3_walls_only',
      totalSheetCount: 8,
      wastePercent: 0,
      jointTapeLength: 240000,
    ),
    SolverBenchmarkCurrentResultV1(
      scenarioId: 'square_3x3_with_ceiling',
      totalSheetCount: 12,
      wastePercent: 10.5,
      jointTapeLength: 330000,
    ),
    SolverBenchmarkCurrentResultV1(
      scenarioId: 'bedroom_4_2x3_6_with_ceiling',
      totalSheetCount: 14,
      wastePercent: 12.3,
      jointTapeLength: 432000,
    ),
    SolverBenchmarkCurrentResultV1(
      scenarioId: 'living_5_4x3_6_walls_only',
      totalSheetCount: 10,
      wastePercent: 10,
      jointTapeLength: 408000,
    ),
    SolverBenchmarkCurrentResultV1(
      scenarioId: 'hallway_7_2x3_0_with_ceiling',
      totalSheetCount: 20,
      wastePercent: 18.4,
      jointTapeLength: 660000,
    ),
    SolverBenchmarkCurrentResultV1(
      scenarioId: 'open_room_6_0x5_4_with_ceiling',
      totalSheetCount: 25,
      wastePercent: 21.1,
      jointTapeLength: 858000,
    ),
    SolverBenchmarkCurrentResultV1(
      scenarioId: 'notched_family_room_with_ceiling',
      totalSheetCount: 17,
      wastePercent: 16.5,
      jointTapeLength: 612000,
    ),
    SolverBenchmarkCurrentResultV1(
      scenarioId: 'large_ceiling_13_184x5_413',
      totalSheetCount: 44,
      wastePercent: 14.7,
      jointTapeLength: 1703760,
    ),
  ],
);
