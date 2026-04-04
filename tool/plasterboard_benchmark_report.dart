import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';

import '../test/fixtures/plaster_solver/v1/current_results_v1.dart';
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
    final recordedByScenarioId = corpus.snapshotsByScenarioId;
    final legacyByScenarioId = {
      for (final result in plasterSolverLegacyResultsV1.results)
        result.scenarioId: result,
    };

    final scenarioRows = <_ScenarioRow>[];
    for (final scenario in corpus.scenarios) {
      final baseline = corpus.baselinesByScenarioId[scenario.id]!;
      final current = calculateSolverBenchmarkMetrics(
        scenario.shapes,
        materials,
      );
      scenarioRows.add(
        _ScenarioRow(
          scenarioName: scenario.name,
          baseline: baseline,
          current: current,
          recorded: recordedByScenarioId[scenario.id],
          legacy: legacyByScenarioId[scenario.id],
        ),
      );
    }

    final currentAggregate = _buildCurrentAggregate(scenarioRows);
    final recordedAggregate = _buildSnapshotAggregate(
      scenarioRows,
      kind: _SnapshotKind.recorded,
    );
    final legacyAggregate = _buildSnapshotAggregate(
      scenarioRows,
      kind: _SnapshotKind.legacy,
    );

    print(
      'Plasterboard solver benchmark report '
      '(schema v${corpus.schemaVersion}, scoring ${corpus.scoringVersion})',
    );
    print('');
    print('Scenario comparison');
    print(
      '| Scenario | Live | ${plasterSolverCurrentResultsV1.solverFamily} | '
      '${plasterSolverLegacyResultsV1.solverFamily} | Baseline |',
    );
    print('| --- | --- | --- | --- | --- |');
    for (final row in scenarioRows) {
      print(
        '| ${row.scenarioName} | '
        '${_formatCurrentMetrics(row.current)} | '
        '${_formatSnapshotMetrics(row.recorded)} | '
        '${_formatLegacyMetrics(row.legacy)} | '
        '${_formatBaseline(row.baseline)} |',
      );
    }

    print('');
    print('Aggregate comparison');
    final currentHeader = plasterSolverCurrentResultsV1.solverFamily;
    final legacyHeader = plasterSolverLegacyResultsV1.solverFamily;
    final liveSurfaceArea = _formatSquareMeters(
      currentAggregate.totalSurfaceArea,
    );
    final recordedSurfaceArea = _formatNullableSquareMeters(
      recordedAggregate?.totalSurfaceArea,
    );
    final legacySurfaceArea = _formatNullableSquareMeters(
      legacyAggregate?.totalSurfaceArea,
    );
    final recordedWasteArea = _formatNullableSquareMeters(
      recordedAggregate?.totalEstimatedWasteArea,
    );
    final legacyWasteArea = _formatNullableSquareMeters(
      legacyAggregate?.totalEstimatedWasteArea,
    );
    print('| Metric | Live | $currentHeader | $legacyHeader |');
    print('| --- | --- | --- | --- |');
    print(
      '| Sheets | ${currentAggregate.totalSheets} | '
      '${_formatNullableInt(recordedAggregate?.totalSheets)} | '
      '${_formatNullableInt(legacyAggregate?.totalSheets)} |',
    );
    print(
      '| Surface area | $liveSurfaceArea | '
      '$recordedSurfaceArea | $legacySurfaceArea |',
    );
    print(
      '| Purchased board area | '
      '${_formatSquareMeters(currentAggregate.totalPurchasedBoardArea)} | '
      'n/a | n/a |',
    );
    print(
      '| Estimated waste area | '
      '${_formatSquareMeters(currentAggregate.totalEstimatedWasteArea)} | '
      '$recordedWasteArea | $legacyWasteArea |',
    );
    print(
      '| Weighted waste | '
      '${currentAggregate.weightedWastePercent.toStringAsFixed(1)}% | '
      '${_formatNullablePercent(recordedAggregate?.weightedWastePercent)} | '
      '${_formatNullablePercent(legacyAggregate?.weightedWastePercent)} |',
    );
    print(
      '| Joint tape | ${_formatMeters(currentAggregate.totalJointTape)} | '
      '${_formatNullableMeters(recordedAggregate?.totalJointTape)} | '
      '${_formatNullableMeters(legacyAggregate?.totalJointTape)} |',
    );

    print('');
    print('Aggregate delta vs snapshots');
    print('| Comparison | Sheets | Weighted waste | Joint tape |');
    print('| --- | --- | --- | --- |');
    final recordedSheetDelta = recordedAggregate == null
        ? null
        : currentAggregate.totalSheets - recordedAggregate.totalSheets;
    final recordedWasteDelta = recordedAggregate == null
        ? null
        : currentAggregate.weightedWastePercent -
              recordedAggregate.weightedWastePercent;
    final recordedTapeDelta = recordedAggregate == null
        ? null
        : currentAggregate.totalJointTape - recordedAggregate.totalJointTape;
    print(
      '| Live vs $currentHeader | '
      '${_formatSignedNullableInt(recordedSheetDelta)} | '
      '${_formatSignedNullablePercent(recordedWasteDelta)} | '
      '${_formatSignedNullableMeters(recordedTapeDelta)} |',
    );
    final legacySheetDelta = legacyAggregate == null
        ? null
        : currentAggregate.totalSheets - legacyAggregate.totalSheets;
    final legacyWasteDelta = legacyAggregate == null
        ? null
        : currentAggregate.weightedWastePercent -
              legacyAggregate.weightedWastePercent;
    final legacyTapeDelta = legacyAggregate == null
        ? null
        : currentAggregate.totalJointTape - legacyAggregate.totalJointTape;
    print(
      '| Live vs $legacyHeader | '
      '${_formatSignedNullableInt(legacySheetDelta)} | '
      '${_formatSignedNullablePercent(legacyWasteDelta)} | '
      '${_formatSignedNullableMeters(legacyTapeDelta)} |',
    );
  } finally {
    PlasterGeometry.debugSurfaceCandidateLogging = previousLogging;
  }
}

class _ScenarioRow {
  final String scenarioName;
  final SolverBenchmarkBaseline baseline;
  final SolverBenchmarkMetrics current;
  final SolverBenchmarkSnapshot? recorded;
  final SolverBenchmarkLegacyResultV1? legacy;

  const _ScenarioRow({
    required this.scenarioName,
    required this.baseline,
    required this.current,
    required this.recorded,
    required this.legacy,
  });
}

class _AggregateMetrics {
  final int totalSheets;
  final int totalSurfaceArea;
  final int totalPurchasedBoardArea;
  final int totalEstimatedWasteArea;
  final double weightedWastePercent;
  final int totalJointTape;

  const _AggregateMetrics({
    required this.totalSheets,
    required this.totalSurfaceArea,
    required this.totalPurchasedBoardArea,
    required this.totalEstimatedWasteArea,
    required this.weightedWastePercent,
    required this.totalJointTape,
  });
}

enum _SnapshotKind { recorded, legacy }

_AggregateMetrics _buildCurrentAggregate(List<_ScenarioRow> rows) {
  var totalSheets = 0;
  var totalSurfaceArea = 0;
  var totalPurchasedBoardArea = 0;
  var totalEstimatedWasteArea = 0;
  var totalJointTape = 0;

  for (final row in rows) {
    totalSheets += row.current.totalSheetCount;
    totalSurfaceArea += row.current.surfaceArea;
    totalPurchasedBoardArea += row.current.purchasedBoardArea;
    totalEstimatedWasteArea += row.current.estimatedWasteArea;
    totalJointTape += row.current.jointTapeLength;
  }

  return _AggregateMetrics(
    totalSheets: totalSheets,
    totalSurfaceArea: totalSurfaceArea,
    totalPurchasedBoardArea: totalPurchasedBoardArea,
    totalEstimatedWasteArea: totalEstimatedWasteArea,
    weightedWastePercent: totalSurfaceArea == 0
        ? 0
        : (totalEstimatedWasteArea / totalSurfaceArea) * 100,
    totalJointTape: totalJointTape,
  );
}

_AggregateMetrics? _buildSnapshotAggregate(
  List<_ScenarioRow> rows, {
  required _SnapshotKind kind,
}) {
  var totalSheets = 0;
  var totalSurfaceArea = 0;
  var totalEstimatedWasteArea = 0.0;
  var totalJointTape = 0;
  var hasAny = false;

  for (final row in rows) {
    if (kind == _SnapshotKind.recorded) {
      final snapshot = row.recorded;
      if (snapshot == null) {
        continue;
      }
      hasAny = true;
      totalSheets += snapshot.totalSheetCount;
      totalSurfaceArea += row.current.surfaceArea;
      totalEstimatedWasteArea +=
          (snapshot.wastePercent / 100.0) * row.current.surfaceArea;
      totalJointTape += snapshot.jointTapeLength;
      continue;
    }
    final snapshot = row.legacy;
    if (snapshot == null) {
      continue;
    }
    hasAny = true;
    totalSheets += snapshot.totalSheetCount;
    totalSurfaceArea += row.current.surfaceArea;
    totalEstimatedWasteArea +=
        (snapshot.wastePercent / 100.0) * row.current.surfaceArea;
    totalJointTape += snapshot.jointTapeLength;
  }

  if (!hasAny) {
    return null;
  }

  return _AggregateMetrics(
    totalSheets: totalSheets,
    totalSurfaceArea: totalSurfaceArea,
    totalPurchasedBoardArea: 0,
    totalEstimatedWasteArea: totalEstimatedWasteArea.round(),
    weightedWastePercent: totalSurfaceArea == 0
        ? 0
        : (totalEstimatedWasteArea / totalSurfaceArea) * 100,
    totalJointTape: totalJointTape,
  );
}

String _formatCurrentMetrics(SolverBenchmarkMetrics metrics) =>
    '${metrics.totalSheetCount} / '
    '${metrics.wastePercent.toStringAsFixed(1)}% / '
    '${_formatMeters(metrics.jointTapeLength)}';

String _formatSnapshotMetrics(SolverBenchmarkSnapshot? snapshot) {
  if (snapshot == null) {
    return 'n/a';
  }
  return '${snapshot.totalSheetCount} / '
      '${snapshot.wastePercent.toStringAsFixed(1)}% / '
      '${_formatMeters(snapshot.jointTapeLength)}';
}

String _formatLegacyMetrics(SolverBenchmarkLegacyResultV1? snapshot) {
  if (snapshot == null) {
    return 'n/a';
  }
  return '${snapshot.totalSheetCount} / '
      '${snapshot.wastePercent.toStringAsFixed(1)}% / '
      '${_formatMeters(snapshot.jointTapeLength)}';
}

String _formatBaseline(SolverBenchmarkBaseline baseline) =>
    '<= ${baseline.maxSheets} / '
    '<= ${baseline.maxWastePercent.toStringAsFixed(1)}% / '
    '<= ${_formatMeters(baseline.maxJointTapeLength)}';

String _formatMeters(int value) => '${_ceilMetricMeters(value)} m';

String _formatSquareMeters(int value) =>
    '${(value / 100000000).toStringAsFixed(2)} m²';

String _formatNullableInt(int? value) => value?.toString() ?? 'n/a';

String _formatNullablePercent(double? value) =>
    value == null ? 'n/a' : '${value.toStringAsFixed(1)}%';

String _formatNullableMeters(int? value) =>
    value == null ? 'n/a' : _formatMeters(value);

String _formatNullableSquareMeters(int? value) =>
    value == null ? 'n/a' : _formatSquareMeters(value);

String _formatSignedNullableInt(int? value) {
  if (value == null) {
    return 'n/a';
  }
  return value > 0 ? '+$value' : '$value';
}

String _formatSignedNullablePercent(double? value) {
  if (value == null) {
    return 'n/a';
  }
  final formatted = value.toStringAsFixed(1);
  return value > 0 ? '+$formatted%' : '$formatted%';
}

String _formatSignedNullableMeters(int? value) {
  if (value == null) {
    return 'n/a';
  }
  final meters = _ceilMetricMeters(value.abs());
  final prefix = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  return '$prefix$meters m';
}

int _ceilMetricMeters(int value) => (value.abs() + 9999) ~/ 10000;
