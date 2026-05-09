class SolverBenchmarkLegacyResultsV1 {
  final int schemaVersion;
  final String scoringVersion;
  final String solverFamily;
  final List<SolverBenchmarkLegacyResultV1> results;

  const SolverBenchmarkLegacyResultsV1({
    required this.schemaVersion,
    required this.scoringVersion,
    required this.solverFamily,
    required this.results,
  });
}

class SolverBenchmarkLegacyResultV1 {
  final String scenarioId;
  final int totalSheetCount;
  final double wastePercent;
  final int jointTapeLength;

  const SolverBenchmarkLegacyResultV1({
    required this.scenarioId,
    required this.totalSheetCount,
    required this.wastePercent,
    required this.jointTapeLength,
  });
}

const plasterSolverLegacyResultsV1 = SolverBenchmarkLegacyResultsV1(
  schemaVersion: 1,
  scoringVersion: 'v1',
  solverFamily: 'deterministic_layout_v1_pre_field_cuts',
  results: [
    SolverBenchmarkLegacyResultV1(
      scenarioId: 'square_3x3_walls_only',
      totalSheetCount: 10,
      wastePercent: 25,
      jointTapeLength: 240000,
    ),
    SolverBenchmarkLegacyResultV1(
      scenarioId: 'square_3x3_with_ceiling',
      totalSheetCount: 15,
      wastePercent: 33.3,
      jointTapeLength: 330000,
    ),
    SolverBenchmarkLegacyResultV1(
      scenarioId: 'bedroom_4_2x3_6_with_ceiling',
      totalSheetCount: 18,
      wastePercent: 47.9,
      jointTapeLength: 432000,
    ),
    SolverBenchmarkLegacyResultV1(
      scenarioId: 'living_5_4x3_6_walls_only',
      totalSheetCount: 14,
      wastePercent: 53.3,
      jointTapeLength: 408000,
    ),
    SolverBenchmarkLegacyResultV1(
      scenarioId: 'hallway_7_2x3_0_with_ceiling',
      totalSheetCount: 25,
      wastePercent: 43.4,
      jointTapeLength: 660000,
    ),
    SolverBenchmarkLegacyResultV1(
      scenarioId: 'open_room_6_0x5_4_with_ceiling',
      totalSheetCount: 27,
      wastePercent: 37.2,
      jointTapeLength: 858000,
    ),
    SolverBenchmarkLegacyResultV1(
      scenarioId: 'notched_family_room_with_ceiling',
      totalSheetCount: 22,
      wastePercent: 48.4,
      jointTapeLength: 612000,
    ),
    SolverBenchmarkLegacyResultV1(
      scenarioId: 'large_ceiling_13_184x5_413',
      totalSheetCount: 40,
      wastePercent: 16.5,
      jointTapeLength: 1625630,
    ),
  ],
);
