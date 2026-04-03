class SolverBenchmarkBaselineSetV1 {
  final int schemaVersion;
  final String scoringVersion;
  final String solverFamily;
  final List<SolverBenchmarkBaselineV1> baselines;

  const SolverBenchmarkBaselineSetV1({
    required this.schemaVersion,
    required this.scoringVersion,
    required this.solverFamily,
    required this.baselines,
  });
}

class SolverBenchmarkBaselineV1 {
  final String scenarioId;
  final int maxSheets;
  final double maxWastePercent;
  final int maxJointTapeLength;

  const SolverBenchmarkBaselineV1({
    required this.scenarioId,
    required this.maxSheets,
    required this.maxWastePercent,
    required this.maxJointTapeLength,
  });
}

const plasterSolverBaselineResultsV1 = SolverBenchmarkBaselineSetV1(
  schemaVersion: 1,
  scoringVersion: 'v1',
  solverFamily: 'deterministic_layout_v1',
  baselines: [
    SolverBenchmarkBaselineV1(
      scenarioId: 'square_3x3_walls_only',
      maxSheets: 12,
      maxWastePercent: 150,
      maxJointTapeLength: 260000,
    ),
    SolverBenchmarkBaselineV1(
      scenarioId: 'square_3x3_with_ceiling',
      maxSheets: 15,
      maxWastePercent: 150,
      maxJointTapeLength: 350000,
    ),
    SolverBenchmarkBaselineV1(
      scenarioId: 'bedroom_4_2x3_6_with_ceiling',
      maxSheets: 26,
      maxWastePercent: 150,
      maxJointTapeLength: 550000,
    ),
    SolverBenchmarkBaselineV1(
      scenarioId: 'living_5_4x3_6_walls_only',
      maxSheets: 16,
      maxWastePercent: 150,
      maxJointTapeLength: 450000,
    ),
    SolverBenchmarkBaselineV1(
      scenarioId: 'hallway_7_2x3_0_with_ceiling',
      maxSheets: 28,
      maxWastePercent: 170,
      maxJointTapeLength: 750000,
    ),
    SolverBenchmarkBaselineV1(
      scenarioId: 'open_room_6_0x5_4_with_ceiling',
      maxSheets: 40,
      maxWastePercent: 180,
      maxJointTapeLength: 950000,
    ),
    SolverBenchmarkBaselineV1(
      scenarioId: 'notched_family_room_with_ceiling',
      maxSheets: 34,
      maxWastePercent: 180,
      maxJointTapeLength: 850000,
    ),
  ],
);
