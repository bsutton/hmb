import 'dart:convert';
import 'dart:io';

import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';
import 'package:plasterboard_explorer/plasterboard_explorer_models.dart';

import '../test/util/plaster_solver_benchmark_support.dart';

void main(List<String> args) {
  final previousLogging = PlasterGeometry.debugSurfaceCandidateLogging;
  PlasterGeometry.debugSurfaceCandidateLogging = false;
  try {
    final outputPath = _optionValue(args, '--output');
    final solverFamily =
        _optionValue(args, '--solver-family') ?? 'deterministic_layout_v1';
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
    final snapshotSet = BenchmarkVisualSnapshotSet(
      schemaVersion: corpus.schemaVersion,
      scoringVersion: corpus.scoringVersion,
      solverFamily: solverFamily,
      scenarios: [
        for (final scenario in corpus.scenarios)
          calculateBenchmarkVisualSnapshot(scenario, materials),
      ],
    );
    final jsonOutput = const JsonEncoder.withIndent(
      '  ',
    ).convert(snapshotSet.toJson());
    if (outputPath != null && outputPath.isNotEmpty) {
      File(outputPath).writeAsStringSync('$jsonOutput\n');
      print('Wrote benchmark visual snapshot to $outputPath');
    } else {
      print(jsonOutput);
    }
  } finally {
    PlasterGeometry.debugSurfaceCandidateLogging = previousLogging;
  }
}

String? _optionValue(List<String> arguments, String optionName) {
  final optionIndex = arguments.indexOf(optionName);
  if (optionIndex == -1 || optionIndex + 1 >= arguments.length) {
    return null;
  }
  return arguments[optionIndex + 1];
}
