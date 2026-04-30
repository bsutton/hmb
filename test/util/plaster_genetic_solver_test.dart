import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';

import '../../tool/plasterboard_genetic_solver.dart';
import 'plaster_solver_benchmark_support.dart';

void main() {
  group('GeneticPlasterSolver', () {
    test('stays waste-competitive with deterministic benchmark layouts', () {
      final corpus = loadPlasterSolverBenchmarkCorpus();
      final materials = _defaultMaterials();
      for (final scenario in corpus.scenarios) {
        final deterministicLayouts = PlasterGeometry.calculateLayout(
          scenario.shapes,
          materials,
        );
        final deterministicTakeoff = PlasterGeometry.calculateTakeoff(
          scenario.shapes,
          deterministicLayouts,
          0,
        );
        final genetic = GeneticPlasterSolver.solve(
          roomShapes: scenario.shapes,
          materials: materials,
          config: const GeneticPlasterSolverConfig(
            populationSize: 24,
            generations: 20,
            eliteCount: 4,
            mutationRate: 0.24,
          ),
        );

        expect(
          genetic.takeoff.estimatedWastePercent,
          lessThanOrEqualTo(deterministicTakeoff.estimatedWastePercent + 0.01),
          reason:
              '${scenario.name}: GA waste '
              '${genetic.takeoff.estimatedWastePercent.toStringAsFixed(2)}% '
              'should not exceed deterministic waste '
              '${deterministicTakeoff.estimatedWastePercent.toStringAsFixed(2)}'
              '%',
        );
        expect(
          genetic.takeoff.purchasedBoardArea,
          greaterThanOrEqualTo(genetic.takeoff.surfaceArea),
          reason: '${scenario.name}: GA must not under-purchase board area.',
        );
        for (final layout in genetic.layouts) {
          expect(
            _hasStaggerViolation(layout),
            isFalse,
            reason:
                '${scenario.name}: ${layout.label} has adjacent sheet seams '
                'closer than the minimum stagger distance.',
          );
          expect(
            _hasAdjacentHalfCourses(layout),
            isFalse,
            reason:
                '${scenario.name}: ${layout.label} has adjacent half-height '
                'courses; horizontal walls should place the starter half '
                'course at the base.',
          );
          if (!layout.isCeiling) {
            expect(
              _hasBottomHalfStarter(layout),
              isTrue,
              reason:
                  '${scenario.name}: ${layout.label} should use a half-height '
                  'starter course at the base.',
            );
          }
        }
      }
    });
  });
}

bool _hasBottomHalfStarter(PlasterSurfaceLayout layout) {
  final rowHeights = _rowHeights(layout);
  if (rowHeights.isEmpty) {
    return false;
  }
  final materialDepth = min(layout.material.width, layout.material.height);
  final halfDepth = materialDepth ~/ 2;
  return rowHeights.last == halfDepth;
}

bool _hasAdjacentHalfCourses(PlasterSurfaceLayout layout) {
  if (layout.isCeiling) {
    return false;
  }
  final materialDepth = min(layout.material.width, layout.material.height);
  final halfDepth = materialDepth ~/ 2;
  final rowHeights = _rowHeights(layout);
  for (var i = 0; i < rowHeights.length - 1; i++) {
    if (rowHeights[i] == halfDepth && rowHeights[i + 1] == halfDepth) {
      return true;
    }
  }
  return false;
}

List<int> _rowHeights(PlasterSurfaceLayout layout) {
  final rowsByY = <int, int>{};
  for (final placement in layout.placements) {
    rowsByY[placement.y] = placement.height;
  }
  return (rowsByY.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key)))
      .map((entry) => entry.value)
      .toList();
}

bool _hasStaggerViolation(PlasterSurfaceLayout layout) {
  final minStagger = PlasterGeometry.minEdgePiece(layout.material.unitSystem);
  final rowsByY = <int, List<PlasterSheetPlacement>>{};
  for (final placement in layout.placements) {
    rowsByY.putIfAbsent(placement.y, () => []).add(placement);
  }
  final orderedRows = rowsByY.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  for (var i = 0; i < orderedRows.length - 1; i++) {
    final upper = _internalVerticalJoints(orderedRows[i].value, layout.width);
    final lower = _internalVerticalJoints(
      orderedRows[i + 1].value,
      layout.width,
    );
    for (final leftJoint in upper) {
      for (final rightJoint in lower) {
        if ((leftJoint - rightJoint).abs() < minStagger) {
          return true;
        }
      }
    }
  }
  return false;
}

List<int> _internalVerticalJoints(
  List<PlasterSheetPlacement> row,
  int surfaceWidth,
) {
  final joints = <int>{};
  for (final placement in row) {
    final joint = placement.x + placement.width;
    if (joint > 0 && joint < surfaceWidth) {
      joints.add(joint);
    }
  }
  return joints.toList()..sort();
}

List<PlasterMaterialSize> _defaultMaterials() => [
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
