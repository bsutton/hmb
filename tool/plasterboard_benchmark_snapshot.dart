import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';

import '../test/util/plaster_solver_benchmark_support.dart';

void main() {
  final previousLogging = PlasterGeometry.debugSurfaceCandidateLogging;
  PlasterGeometry.debugSurfaceCandidateLogging = false;
  try {
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

    final corpus = loadPlasterSolverBenchmarkCorpus();
    print('[');
    for (var i = 0; i < corpus.scenarios.length; i++) {
      final scenario = corpus.scenarios[i];
      final metrics = calculateSolverBenchmarkMetrics(
        scenario.shapes,
        materials,
      );
      print('  SolverBenchmarkCurrentResultV1(');
      print("    scenarioId: '${scenario.id}',");
      print('    totalSheetCount: ${metrics.totalSheetCount},');
      print('    wastePercent: ${metrics.wastePercent.toStringAsFixed(1)},');
      print('    jointTapeLength: ${metrics.jointTapeLength},');
      print('  )${i == corpus.scenarios.length - 1 ? '' : ','}');
    }
    print(']');
  } finally {
    PlasterGeometry.debugSurfaceCandidateLogging = previousLogging;
  }
}
