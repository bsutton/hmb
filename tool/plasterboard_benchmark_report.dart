import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';

import '../test/fixtures/plaster_solver/v1/legacy_results_v1.dart';
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
    print(
      'Plasterboard solver benchmark report '
      '(schema v${corpus.schemaVersion}, '
      'scoring ${corpus.scoringVersion})',
    );
    print('');

    var totalSheets = 0;
    var totalSheetHeadroom = 0;
    var totalSurfaceArea = 0;
    var totalPurchasedBoardArea = 0;
    var totalEstimatedWasteArea = 0;
    var totalTape = 0;
    var totalTapeHeadroom = 0;
    var totalRecordedSheets = 0;
    var totalRecordedTape = 0;
    var totalRecordedSurfaceArea = 0;
    var totalRecordedWasteArea = 0.0;
    final legacyByScenarioId = {
      for (final result in plasterSolverLegacyResultsV1.results)
        result.scenarioId: result,
    };
    var totalLegacySheets = 0;
    var totalLegacyTape = 0;
    var totalLegacySurfaceArea = 0;
    var totalLegacyWasteArea = 0.0;
    final missingLegacyScenarioIds = <String>[];

    for (final scenario in corpus.scenarios) {
      final baseline = corpus.baselinesByScenarioId[scenario.id]!;
      final snapshot = corpus.snapshotsByScenarioId[scenario.id];
      final legacy = legacyByScenarioId[scenario.id];
      final metrics = calculateSolverBenchmarkMetrics(
        scenario.shapes,
        materials,
      );
      final wasteHeadroom = baseline.maxWastePercent - metrics.wastePercent;
      totalSheets += metrics.totalSheetCount;
      totalSheetHeadroom += baseline.maxSheets - metrics.totalSheetCount;
      totalSurfaceArea += metrics.surfaceArea;
      totalPurchasedBoardArea += metrics.purchasedBoardArea;
      totalEstimatedWasteArea += metrics.estimatedWasteArea;
      totalTape += metrics.jointTapeLength;
      totalTapeHeadroom +=
          baseline.maxJointTapeLength - metrics.jointTapeLength;
      final sheetDelta = snapshot == null
          ? null
          : metrics.totalSheetCount - snapshot.totalSheetCount;
      final wasteDelta = snapshot == null
          ? null
          : metrics.wastePercent - snapshot.wastePercent;
      final tapeDelta = snapshot == null
          ? null
          : metrics.jointTapeLength - snapshot.jointTapeLength;
      final legacySheetDelta = legacy == null
          ? null
          : metrics.totalSheetCount - legacy.totalSheetCount;
      final legacyWasteDelta = legacy == null
          ? null
          : metrics.wastePercent - legacy.wastePercent;
      final legacyTapeDelta = legacy == null
          ? null
          : metrics.jointTapeLength - legacy.jointTapeLength;
      if (snapshot != null) {
        totalRecordedSheets += snapshot.totalSheetCount;
        totalRecordedTape += snapshot.jointTapeLength;
        totalRecordedSurfaceArea += metrics.surfaceArea;
        totalRecordedWasteArea +=
            (snapshot.wastePercent / 100.0) * metrics.surfaceArea;
      }
      if (legacy != null) {
        totalLegacySheets += legacy.totalSheetCount;
        totalLegacyTape += legacy.jointTapeLength;
        totalLegacySurfaceArea += metrics.surfaceArea;
        totalLegacyWasteArea +=
            (legacy.wastePercent / 100.0) * metrics.surfaceArea;
      } else if (_isWholeRoomScenario(scenario)) {
        missingLegacyScenarioIds.add(scenario.id);
      }
      final tapeHeadroom =
          baseline.maxJointTapeLength - metrics.jointTapeLength;

      print(scenario.name);
      print('  id: ${scenario.id}');
      print(
        '  sheets: ${metrics.totalSheetCount} '
        '(baseline <= ${baseline.maxSheets}, '
        'headroom ${baseline.maxSheets - metrics.totalSheetCount})',
      );
      print(
        '  waste: ${metrics.wastePercent.toStringAsFixed(1)}% '
        '(baseline <= ${baseline.maxWastePercent.toStringAsFixed(1)}%, '
        'headroom ${wasteHeadroom.toStringAsFixed(1)}%)',
      );
      print(
        '  joint tape: ${_formatMeters(metrics.jointTapeLength)} '
        '(baseline <= ${_formatMeters(baseline.maxJointTapeLength)}, '
        'headroom ${_formatSignedMeters(tapeHeadroom)})',
      );
      if (snapshot != null) {
        print(
          '  delta vs recorded result: '
          'sheets ${_formatSignedInt(sheetDelta!)}, '
          'waste ${_formatSignedDouble(wasteDelta!)}%, '
          'joint tape ${_formatSignedMeters(tapeDelta!)}',
        );
      }
      if (legacy != null) {
        print(
          '  delta vs legacy solver: '
          'sheets ${_formatSignedInt(legacySheetDelta!)}, '
          'waste ${_formatSignedDouble(legacyWasteDelta!)}%, '
          'joint tape ${_formatSignedMeters(legacyTapeDelta!)}',
        );
      } else if (_isWholeRoomScenario(scenario)) {
        print('  delta vs legacy solver: n/a (no full-room legacy snapshot)');
      }
      print('');
    }

    final weightedWastePercent = totalSurfaceArea == 0
        ? 0.0
        : (totalEstimatedWasteArea / totalSurfaceArea) * 100;

    print('Aggregate');
    print('  sheets total: $totalSheets');
    print('  surface area total: ${_formatSquareMeters(totalSurfaceArea)}');
    print(
      '  purchased board area total: '
      '${_formatSquareMeters(totalPurchasedBoardArea)}',
    );
    print(
      '  estimated waste area total: '
      '${_formatSquareMeters(totalEstimatedWasteArea)}',
    );
    print(
      '  weighted waste percent: '
      '${weightedWastePercent.toStringAsFixed(1)}%',
    );
    print('  joint tape total: ${_formatMeters(totalTape)}');
    if (totalRecordedSurfaceArea > 0) {
      final recordedWeightedWastePercent =
          (totalRecordedWasteArea / totalRecordedSurfaceArea) * 100;
      final recordedWasteDelta =
          weightedWastePercent - recordedWeightedWastePercent;
      print('');
      print('Aggregate delta vs recorded result snapshot');
      print('  sheets: ${_formatSignedInt(totalSheets - totalRecordedSheets)}');
      print(
        '  weighted waste: '
        '${_formatSignedDouble(recordedWasteDelta)}%',
      );
      print(
        '  joint tape: '
        '${_formatSignedMeters(totalTape - totalRecordedTape)}',
      );
    }
    if (totalLegacySurfaceArea > 0) {
      final legacyWeightedWastePercent =
          (totalLegacyWasteArea / totalLegacySurfaceArea) * 100;
      final legacyWasteDelta =
          weightedWastePercent - legacyWeightedWastePercent;
      print('');
      print('Aggregate delta vs legacy solver snapshot');
      print('  sheets: ${_formatSignedInt(totalSheets - totalLegacySheets)}');
      print(
        '  weighted waste: '
        '${_formatSignedDouble(legacyWasteDelta)}%',
      );
      print(
        '  joint tape: ${_formatSignedMeters(totalTape - totalLegacyTape)}',
      );
    }
    if (missingLegacyScenarioIds.isNotEmpty) {
      print('');
      print(
        'Legacy snapshot missing for full-room scenarios: '
        '${missingLegacyScenarioIds.join(', ')}',
      );
    }
    print('');
    print('Aggregate baseline headroom');
    print('  sheets: $totalSheetHeadroom');
    print('  joint tape: ${_formatSignedMeters(totalTapeHeadroom)}');
  } finally {
    PlasterGeometry.debugSurfaceCandidateLogging = previousLogging;
  }
}

String _formatSignedInt(int value) => value > 0 ? '+$value' : '$value';

String _formatSignedDouble(double value) {
  final formatted = value.toStringAsFixed(1);
  return value > 0 ? '+$formatted' : formatted;
}

String _formatMeters(int value) => '${_ceilMetricMeters(value)} m';

String _formatSquareMeters(int value) =>
    '${(value / 100000000).toStringAsFixed(2)} m²';

String _formatSignedMeters(int value) {
  final meters = _ceilMetricMeters(value.abs());
  final prefix = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  return '$prefix$meters m';
}

int _ceilMetricMeters(int value) => (value.abs() + 9999) ~/ 10000;

bool _isWholeRoomScenario(SolverBenchmarkScenario scenario) =>
    scenario.shapes.every((shape) => shape.room.plasterCeiling);
