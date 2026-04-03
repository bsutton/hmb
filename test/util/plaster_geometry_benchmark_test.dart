import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';

import 'plaster_solver_benchmark_support.dart';

void main() {
  group('PlasterGeometry benchmark layouts', () {
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

    test('versioned baseline room corpus stays within thresholds', () {
      final corpus = loadPlasterSolverBenchmarkCorpus();
      for (final scenario in corpus.scenarios) {
        final baseline = corpus.baselinesByScenarioId[scenario.id]!;
        final metrics = calculateSolverBenchmarkMetrics(
          scenario.shapes,
          materials,
        );

        expect(
          metrics.totalSheetCount,
          lessThanOrEqualTo(baseline.maxSheets),
          reason:
              '${scenario.name}: expected <= ${baseline.maxSheets} sheets, '
              'got ${metrics.totalSheetCount}',
        );
        expect(
          metrics.wastePercent,
          lessThanOrEqualTo(baseline.maxWastePercent),
          reason:
              '${scenario.name}: expected <= '
              '${baseline.maxWastePercent.toStringAsFixed(1)}% waste, got '
              '${metrics.wastePercent.toStringAsFixed(1)}%',
        );
        expect(
          metrics.jointTapeLength,
          lessThanOrEqualTo(baseline.maxJointTapeLength),
          reason:
              '${scenario.name}: expected <= ${baseline.maxJointTapeLength} '
              'joint-tape units, got ${metrics.jointTapeLength}',
        );
      }
    });
  });
}
