import 'dart:math';

import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';
import 'package:hmb/util/dart/plaster_sheet_direction.dart';

class GeneticPlasterSolverConfig {
  final int populationSize;
  final int generations;
  final int eliteCount;
  final int seed;
  final double mutationRate;
  final bool includeDeterministicSeed;

  const GeneticPlasterSolverConfig({
    this.populationSize = 48,
    this.generations = 60,
    this.eliteCount = 6,
    this.seed = 1309,
    this.mutationRate = 0.18,
    this.includeDeterministicSeed = true,
  });
}

class GeneticPlasterResult {
  final List<PlasterSurfaceLayout> layouts;
  final PlasterTakeoffSummary takeoff;
  final int evaluatedCandidates;
  final int generationCount;
  final int elapsedMs;
  final double fitness;

  const GeneticPlasterResult({
    required this.layouts,
    required this.takeoff,
    required this.evaluatedCandidates,
    required this.generationCount,
    required this.elapsedMs,
    required this.fitness,
  });
}

class GeneticPlasterSolver {
  static GeneticPlasterResult solve({
    required List<PlasterRoomShape> roomShapes,
    required List<PlasterMaterialSize> materials,
    GeneticPlasterSolverConfig config = const GeneticPlasterSolverConfig(),
  }) {
    final stopwatch = Stopwatch()..start();
    final random = Random(config.seed);
    final materialClasses = _MaterialDepthClass.build(materials);
    if (materialClasses.isEmpty) {
      final takeoff = PlasterGeometry.calculateTakeoff(roomShapes, const [], 0);
      return GeneticPlasterResult(
        layouts: const [],
        takeoff: takeoff,
        evaluatedCandidates: 0,
        generationCount: 0,
        elapsedMs: stopwatch.elapsedMilliseconds,
        fitness: double.infinity,
      );
    }

    final surfaceSpecs = _surfaceSpecs(roomShapes);
    if (surfaceSpecs.isEmpty) {
      final takeoff = PlasterGeometry.calculateTakeoff(roomShapes, const [], 0);
      return GeneticPlasterResult(
        layouts: const [],
        takeoff: takeoff,
        evaluatedCandidates: 0,
        generationCount: 0,
        elapsedMs: stopwatch.elapsedMilliseconds,
        fitness: double.infinity,
      );
    }

    var population = <_ScoredGenome>[];
    if (config.includeDeterministicSeed) {
      final deterministicLayouts = PlasterGeometry.calculateLayout(
        roomShapes,
        materials,
      );
      population.add(
        _scoreGenome(
          _genomeFromLayouts(
            layouts: deterministicLayouts,
            surfaceSpecs: surfaceSpecs,
            materialClasses: materialClasses,
          ),
          roomShapes,
          surfaceSpecs,
        ),
      );
    }

    while (population.length < config.populationSize) {
      population.add(
        _scoreGenome(
          _randomGenome(surfaceSpecs, materialClasses, random),
          roomShapes,
          surfaceSpecs,
        ),
      );
    }
    var evaluatedCandidates = population.length;
    population.sort();

    for (var generation = 0; generation < config.generations; generation++) {
      final next = <_ScoredGenome>[...population.take(config.eliteCount)];
      while (next.length < config.populationSize) {
        final left = _selectParent(population, random).genome;
        final right = _selectParent(population, random).genome;
        final child = _breed(
          left: left,
          right: right,
          surfaceSpecs: surfaceSpecs,
          materialClasses: materialClasses,
          random: random,
          mutationRate: config.mutationRate,
        );
        next.add(_scoreGenome(child, roomShapes, surfaceSpecs));
      }
      evaluatedCandidates += config.populationSize - config.eliteCount;
      next.sort();
      population = next;
    }

    final best = population.first;
    final layouts = _decodeGenome(best.genome, surfaceSpecs);
    final takeoff = PlasterGeometry.calculateTakeoff(roomShapes, layouts, 0);
    return GeneticPlasterResult(
      layouts: layouts,
      takeoff: takeoff,
      evaluatedCandidates: evaluatedCandidates,
      generationCount: config.generations,
      elapsedMs: stopwatch.elapsedMilliseconds,
      fitness: best.fitness,
    );
  }

  static List<_SurfaceSpec> _surfaceSpecs(List<PlasterRoomShape> roomShapes) {
    final specs = <_SurfaceSpec>[];
    for (final shape in roomShapes) {
      for (var i = 0; i < shape.lines.length; i++) {
        final line = shape.lines[i];
        if (!line.plasterSelected) {
          continue;
        }
        specs.add(
          _SurfaceSpec(
            index: specs.length,
            roomShape: shape,
            roomId: shape.room.id,
            lineId: line.id,
            isCeiling: false,
            label: _surfaceLabel(
              '${shape.room.name} wall ${i + 1}',
              line.length,
              shape.room.ceilingHeight,
              shape.room.unitSystem,
            ),
            width: line.length,
            height: shape.room.ceilingHeight,
            area: PlasterGeometry.lineNetArea(
              shape.room,
              shape.lines,
              shape.openings,
              i,
            ),
          ),
        );
      }
      if (shape.room.plasterCeiling) {
        final bounds = _bounds(shape.lines);
        final width = bounds.$3 - bounds.$1;
        final height = bounds.$4 - bounds.$2;
        specs.add(
          _SurfaceSpec(
            index: specs.length,
            roomShape: shape,
            roomId: shape.room.id,
            lineId: null,
            isCeiling: true,
            label: _surfaceLabel(
              '${shape.room.name} ceiling',
              width,
              height,
              shape.room.unitSystem,
            ),
            width: width,
            height: height,
            area: PlasterGeometry.polygonArea(shape.lines),
          ),
        );
      }
    }
    return specs;
  }

  static _Genome _randomGenome(
    List<_SurfaceSpec> surfaceSpecs,
    List<_MaterialDepthClass> materialClasses,
    Random random,
  ) => _Genome([
    for (final spec in surfaceSpecs)
      _randomSurfaceGenome(spec, materialClasses, random),
  ]);

  static _SurfaceGenome _randomSurfaceGenome(
    _SurfaceSpec spec,
    List<_MaterialDepthClass> materialClasses,
    Random random,
  ) {
    final depthClassIndex = _pickDepthClassIndex(materialClasses, random);
    final depthClass = materialClasses[depthClassIndex];
    final materialIndex = _randomMaterialForLength(
      depthClass,
      spec.width,
      random,
    );
    final runDepths = _randomRunDepths(
      surfaceDepth: spec.height,
      materialDepth: depthClass.depth,
      minEdge: PlasterGeometry.minEdgePiece(spec.unitSystem),
      horizontalWallStarter: !spec.isCeiling,
      random: random,
    );
    spec.fallbackMaterialClass = depthClass;
    final surface = _SurfaceGenome(
      specIndex: spec.index,
      runs: [
        for (final depth in runDepths)
          _randomRun(
            surfaceLength: spec.width,
            depthClassIndex: depthClassIndex,
            depthClass: depthClass,
            materialIndex: materialIndex,
            depth: depth,
            random: random,
            unitSystem: spec.unitSystem,
          ),
      ],
    );
    for (final run in surface.runs) {
      run.materialClass = depthClass;
    }
    return surface;
  }

  static _Genome _genomeFromLayouts({
    required List<PlasterSurfaceLayout> layouts,
    required List<_SurfaceSpec> surfaceSpecs,
    required List<_MaterialDepthClass> materialClasses,
  }) {
    final surfaces = <_SurfaceGenome>[];
    for (var specIndex = 0; specIndex < surfaceSpecs.length; specIndex++) {
      final spec = surfaceSpecs[specIndex];
      final matchingLayouts = [
        for (final layout in layouts)
          if (layout.roomId == spec.roomId &&
              layout.lineId == spec.lineId &&
              layout.isCeiling == spec.isCeiling)
            layout,
      ];
      final layout = matchingLayouts.isEmpty
          ? _decodeSurface(
              _repairSurface(
                _randomSurfaceGenome(
                  spec,
                  materialClasses,
                  Random(specIndex + 1),
                ),
                spec,
                materialClasses,
                Random(specIndex + 11),
              ),
              spec,
            )
          : matchingLayouts.first;
      final runsByY = <int, List<PlasterSheetPlacement>>{};
      for (final placement in layout.placements) {
        runsByY.putIfAbsent(placement.y, () => []).add(placement);
      }
      final runs = <_RunGenome>[];
      final orderedY = runsByY.keys.toList()..sort();
      for (final y in orderedY) {
        final placements = runsByY[y]!..sort((a, b) => a.x.compareTo(b.x));
        final depth = placements.first.height;
        final classIndex = _nearestDepthClassIndex(materialClasses, depth);
        final depthClass = materialClasses[classIndex];
        final materialIndex = _nearestMaterialIndex(
          depthClass,
          layout.material.width > layout.material.height
              ? layout.material.width
              : layout.material.height,
        );
        runs.add(
          _RunGenome(
            depthClassIndex: classIndex,
            materialIndex: materialIndex,
            depth: depth,
            sheets: [
              for (final placement in placements)
                _SheetGene(length: placement.width),
            ],
          ),
        );
      }
      surfaces.add(
        _repairSurface(
          _SurfaceGenome(specIndex: specIndex, runs: runs),
          spec,
          materialClasses,
          Random(specIndex + 37),
        ),
      );
    }
    return _Genome(surfaces);
  }

  static _RunGenome _randomRun({
    required int surfaceLength,
    required int depthClassIndex,
    required _MaterialDepthClass depthClass,
    required int materialIndex,
    required int depth,
    required Random random,
    required PreferredUnitSystem unitSystem,
  }) {
    final lengths = _randomSheetLengths(
      surfaceLength: surfaceLength,
      maxPieceLength: depthClass.materials[materialIndex].mainAxisLength,
      minEdge: PlasterGeometry.minEdgePiece(unitSystem),
      random: random,
    );
    return _RunGenome(
      depthClassIndex: depthClassIndex,
      materialIndex: materialIndex,
      depth: depth,
      sheets: [for (final length in lengths) _SheetGene(length: length)],
    )..materialClass = depthClass;
  }

  static List<int> _randomRunDepths({
    required int surfaceDepth,
    required int materialDepth,
    required int minEdge,
    required bool horizontalWallStarter,
    required Random random,
  }) {
    if (horizontalWallStarter && materialDepth ~/ 2 >= minEdge) {
      final starter = min(surfaceDepth, materialDepth ~/ 2);
      if (surfaceDepth == starter) {
        return [starter];
      }
      final remaining = _axisPiecesWithPartialFirst(
        surfaceDepth - starter,
        materialDepth,
        minEdge,
      );
      if (remaining != null && remaining.isNotEmpty) {
        return [...remaining, starter];
      }
    }
    return _randomAxisPieces(
      surfaceLength: surfaceDepth,
      maxPieceLength: materialDepth,
      minEdge: minEdge,
      random: random,
    );
  }

  static List<int> _randomSheetLengths({
    required int surfaceLength,
    required int maxPieceLength,
    required int minEdge,
    required Random random,
  }) => _randomAxisPieces(
    surfaceLength: surfaceLength,
    maxPieceLength: maxPieceLength,
    minEdge: minEdge,
    random: random,
  );

  static List<int> _randomAxisPieces({
    required int surfaceLength,
    required int maxPieceLength,
    required int minEdge,
    required Random random,
  }) {
    if (surfaceLength <= 0) {
      return const [];
    }
    if (surfaceLength <= maxPieceLength) {
      return [surfaceLength];
    }
    final pieces = <int>[];
    var remaining = surfaceLength;
    while (remaining > maxPieceLength) {
      final minRemaining = remaining - maxPieceLength;
      var length = max(minEdge, min(maxPieceLength, remaining - minEdge));
      if (random.nextDouble() < 0.65) {
        length = _randomMultiple(
          minValue: max(minEdge, minRemaining),
          maxValue: min(maxPieceLength, remaining - minEdge),
          step: 3000,
          random: random,
        );
      }
      pieces.add(length);
      remaining -= length;
    }
    if (remaining > 0) {
      if (remaining < minEdge && pieces.isNotEmpty) {
        final deficit = minEdge - remaining;
        final last = pieces.removeLast();
        pieces.add(max(minEdge, last - deficit));
        remaining += deficit;
      }
      pieces.add(remaining);
    }
    return pieces.where((piece) => piece > 0).toList();
  }

  static int _randomMultiple({
    required int minValue,
    required int maxValue,
    required int step,
    required Random random,
  }) {
    if (maxValue <= minValue) {
      return minValue;
    }
    final minStep = (minValue / step).ceil();
    final maxStep = (maxValue / step).floor();
    if (maxStep < minStep) {
      return minValue + random.nextInt(maxValue - minValue + 1);
    }
    return (minStep + random.nextInt(maxStep - minStep + 1)) * step;
  }

  static _Genome _breed({
    required _Genome left,
    required _Genome right,
    required List<_SurfaceSpec> surfaceSpecs,
    required List<_MaterialDepthClass> materialClasses,
    required Random random,
    required double mutationRate,
  }) {
    final surfaces = <_SurfaceGenome>[];
    for (var i = 0; i < left.surfaces.length; i++) {
      final leftSurface = left.surfaces[i];
      final rightSurface = right.surfaces[i];
      final maxRuns = max(leftSurface.runs.length, rightSurface.runs.length);
      final runs = <_RunGenome>[];
      for (var runIndex = 0; runIndex < maxRuns; runIndex++) {
        final source = random.nextBool() ? leftSurface : rightSurface;
        final fallback = identical(source, leftSurface)
            ? rightSurface
            : leftSurface;
        final run = runIndex < source.runs.length
            ? source.runs[runIndex]
            : fallback.runs[min(runIndex, fallback.runs.length - 1)];
        runs.add(run.copy());
      }
      surfaces.add(
        _SurfaceGenome(specIndex: i, runs: runs)..spec = surfaceSpecs[i],
      );
    }
    var child = _Genome(surfaces);
    if (random.nextDouble() < mutationRate) {
      child = _mutate(child, surfaceSpecs, materialClasses, random);
    }
    return _Genome([
      for (var i = 0; i < child.surfaces.length; i++)
        _repairSurface(
          child.surfaces[i],
          child.surfaces[i].spec!,
          materialClasses,
          random,
        ),
    ]);
  }

  static _Genome _mutate(
    _Genome genome,
    List<_SurfaceSpec> surfaceSpecs,
    List<_MaterialDepthClass> materialClasses,
    Random random,
  ) {
    final surfaces = [
      for (var i = 0; i < genome.surfaces.length; i++)
        genome.surfaces[i].copy()..spec = surfaceSpecs[i],
    ];
    final surfaceIndex = random.nextInt(surfaces.length);
    final surface = surfaces[surfaceIndex];
    if (surface.runs.isEmpty) {
      return _Genome(surfaces);
    }
    final runIndex = random.nextInt(surface.runs.length);
    final run = surface.runs[runIndex];
    if (random.nextDouble() < 0.35) {
      final classIndex = _pickDepthClassIndex(materialClasses, random);
      final depthClass = materialClasses[classIndex];
      surface.runs[runIndex] = _randomRun(
        surfaceLength: surface.spec!.width,
        depthClassIndex: classIndex,
        depthClass: depthClass,
        materialIndex: _randomMaterialForLength(
          depthClass,
          surface.spec!.width,
          random,
        ),
        depth: min(run.depth, depthClass.depth),
        random: random,
        unitSystem: surface.spec!.unitSystem,
      );
      surfaces[surfaceIndex] = surface;
      return _Genome(surfaces);
    }
    if (run.sheets.isEmpty) {
      return _Genome(surfaces);
    }
    final sheets = [for (final sheet in run.sheets) sheet.copy()];
    final sheetIndex = random.nextInt(sheets.length);
    final depthClass = materialClasses[run.depthClassIndex];
    final old = sheets[sheetIndex];
    sheets[sheetIndex] = _SheetGene(length: old.length);
    surface.runs[runIndex] = _RunGenome(
      depthClassIndex: run.depthClassIndex,
      materialIndex: _randomMaterialForLength(depthClass, old.length, random),
      depth: run.depth,
      sheets: sheets,
    );
    surfaces[surfaceIndex] = surface;
    return _Genome(surfaces);
  }

  static _ScoredGenome _scoreGenome(
    _Genome genome,
    List<PlasterRoomShape> roomShapes,
    List<_SurfaceSpec> surfaceSpecs,
  ) {
    for (var i = 0; i < genome.surfaces.length; i++) {
      genome.surfaces[i].spec = surfaceSpecs[i];
    }
    final layouts = _decodeGenome(genome, surfaceSpecs);
    final takeoff = PlasterGeometry.calculateTakeoff(roomShapes, layouts, 0);
    final jointTape = layouts.fold<int>(
      0,
      (sum, layout) => sum + layout.estimatedJointTapeLength,
    );
    final weakPiecePenalty = layouts.fold<int>(
      0,
      (sum, layout) =>
          sum +
          layout.placements.where((piece) {
            final minEdge = PlasterGeometry.minEdgePiece(
              layout.material.unitSystem,
            );
            return piece.width < minEdge || piece.height < minEdge;
          }).length,
    );
    final staggerPenalty = layouts.fold<int>(
      0,
      (sum, layout) => sum + _staggerViolationCount(layout),
    );
    final underPurchasedArea = max(
      0,
      takeoff.surfaceArea - takeoff.purchasedBoardArea,
    );
    final fitness =
        underPurchasedArea * 1000 +
        takeoff.estimatedWastePercent * 1000000 +
        takeoff.totalSheetCount * 10000 +
        jointTape / 10 +
        weakPiecePenalty * 500000 +
        staggerPenalty * 100000000;
    return _ScoredGenome(genome: genome, fitness: fitness);
  }

  static List<PlasterSurfaceLayout> _decodeGenome(
    _Genome genome,
    List<_SurfaceSpec> surfaceSpecs,
  ) {
    final layouts = <PlasterSurfaceLayout>[];
    for (var i = 0; i < genome.surfaces.length; i++) {
      layouts.add(_decodeSurface(genome.surfaces[i], surfaceSpecs[i]));
    }
    return layouts;
  }

  static PlasterSurfaceLayout _decodeSurface(
    _SurfaceGenome surface,
    _SurfaceSpec spec,
  ) {
    final placements = <PlasterSheetPlacement>[];
    var y = 0;
    var sheetsAcross = 0;
    for (final run in surface.runs) {
      var x = 0;
      sheetsAcross = max(sheetsAcross, run.sheets.length);
      for (final sheet in run.sheets) {
        placements.add(
          PlasterSheetPlacement(
            x: x,
            y: y,
            width: sheet.length,
            height: run.depth,
          ),
        );
        x += sheet.length;
      }
      y += run.depth;
    }
    final materialClass = surface.runs.isEmpty
        ? spec.fallbackMaterialClass!
        : surface.runs.first.materialClass!;
    final materialIndex = surface.runs.isEmpty
        ? 0
        : surface.runs.first.materialIndex.clamp(
            0,
            materialClass.materials.length - 1,
          );
    final material = materialClass.materials[materialIndex].material;
    return PlasterSurfaceLayout(
      roomId: spec.roomId,
      lineId: spec.lineId,
      isCeiling: spec.isCeiling,
      label: spec.label,
      material: material,
      direction: PlasterSheetDirection.horizontal,
      width: spec.width,
      height: spec.height,
      area: spec.area,
      sheetsAcross: sheetsAcross,
      sheetsDown: surface.runs.length,
      sheetCount: placements.length,
      sheetCountWithWaste: placements.length,
      placements: placements,
      sheetUsage: const [],
      estimatedJointTapeLength: _estimateJointTapeLength(placements),
      estimatedScrewCount: _estimateScrews(spec.area, spec.isCeiling),
      estimatedGlueKg: _estimateGlueKg(spec.area, spec.isCeiling),
      estimatedPlasterKg: _estimatePlasterKg(spec.area),
    );
  }

  static _SurfaceGenome _repairSurface(
    _SurfaceGenome surface,
    _SurfaceSpec spec,
    List<_MaterialDepthClass> materialClasses,
    Random random,
  ) {
    surface.spec = spec;
    if (surface.runs.isEmpty) {
      return _randomSurfaceGenome(spec, materialClasses, random);
    }
    final surfaceDepthClassIndex = surface.runs.first.depthClassIndex.clamp(
      0,
      materialClasses.length - 1,
    );
    final surfaceDepthClass = materialClasses[surfaceDepthClassIndex];
    final surfaceMaterialIndex = surface.runs.first.materialIndex.clamp(
      0,
      surfaceDepthClass.materials.length - 1,
    );
    final targetDepths = _targetRunDepths(
      spec: spec,
      materialDepth: surfaceDepthClass.depth,
      random: random,
    );
    final repairedRuns = <_RunGenome>[];
    for (var i = 0; i < targetDepths.length; i++) {
      final sourceRun = surface.runs[min(i, surface.runs.length - 1)];
      final run = sourceRun
          .withMaterial(
            depthClassIndex: surfaceDepthClassIndex,
            materialIndex: surfaceMaterialIndex,
          )
          .withDepth(targetDepths[i]);
      repairedRuns.add(_repairRun(run, spec, surfaceDepthClass, random));
    }
    final repaired = _SurfaceGenome(
      specIndex: surface.specIndex,
      runs: repairedRuns,
    )..spec = spec;
    for (final run in repaired.runs) {
      run.materialClass = materialClasses[run.depthClassIndex];
    }
    spec.fallbackMaterialClass = surfaceDepthClass;
    return repaired;
  }

  static List<int> _targetRunDepths({
    required _SurfaceSpec spec,
    required int materialDepth,
    required Random random,
  }) {
    final minEdge = PlasterGeometry.minEdgePiece(spec.unitSystem);
    if (!spec.isCeiling && materialDepth ~/ 2 >= minEdge) {
      final starter = min(spec.height, materialDepth ~/ 2);
      if (spec.height == starter) {
        return [starter];
      }
      final upperDepth = spec.height - starter;
      final upperRuns = _axisPiecesWithPartialFirst(
        upperDepth,
        materialDepth,
        minEdge,
      );
      if (upperRuns != null && upperRuns.isNotEmpty) {
        return [...upperRuns, starter];
      }
    }
    final runs = _axisPiecesWithPartialLast(
      spec.height,
      materialDepth,
      minEdge,
    );
    if (runs != null && runs.isNotEmpty) {
      return runs;
    }
    return _randomRunDepths(
      surfaceDepth: spec.height,
      materialDepth: materialDepth,
      minEdge: minEdge,
      horizontalWallStarter: !spec.isCeiling,
      random: random,
    );
  }

  static List<int>? _axisPiecesWithPartialFirst(
    int length,
    int maxPieceLength,
    int minEdge,
  ) {
    if (length <= 0 || maxPieceLength <= 0) {
      return null;
    }
    if (length <= maxPieceLength) {
      return length < minEdge ? null : [length];
    }
    final fullCount = length ~/ maxPieceLength;
    final remainder = length % maxPieceLength;
    if (remainder == 0) {
      return List<int>.filled(fullCount, maxPieceLength);
    }
    if (remainder >= minEdge) {
      return [remainder, ...List<int>.filled(fullCount, maxPieceLength)];
    }
    if (fullCount == 0) {
      return null;
    }
    final borrowed = minEdge - remainder;
    final adjustedFull = maxPieceLength - borrowed;
    if (adjustedFull < minEdge) {
      return null;
    }
    return [
      minEdge,
      adjustedFull,
      ...List<int>.filled(fullCount - 1, maxPieceLength),
    ];
  }

  static List<int>? _axisPiecesWithPartialLast(
    int length,
    int maxPieceLength,
    int minEdge,
  ) {
    final pieces = _axisPiecesWithPartialFirst(length, maxPieceLength, minEdge);
    return pieces?.reversed.toList();
  }

  static _RunGenome _repairRun(
    _RunGenome run,
    _SurfaceSpec spec,
    _MaterialDepthClass depthClass,
    Random random,
  ) {
    var remainingLength = spec.width;
    final minEdge = PlasterGeometry.minEdgePiece(spec.unitSystem);
    final sheets = <_SheetGene>[];
    for (var i = 0; i < run.sheets.length && remainingLength > 0; i++) {
      final old = run.sheets[i];
      final materialIndex = run.materialIndex.clamp(
        0,
        depthClass.materials.length - 1,
      );
      final maxLength = depthClass.materials[materialIndex].mainAxisLength;
      final isLast = i == run.sheets.length - 1;
      var length = min(old.length, maxLength);
      if (isLast || remainingLength - length < minEdge) {
        length = remainingLength;
      }
      if (length > maxLength) {
        break;
      }
      if (length < minEdge && sheets.isNotEmpty) {
        final previous = sheets.removeLast();
        final previousOption = depthClass.materials[materialIndex];
        final merged = previous.length + length;
        if (merged <= previousOption.mainAxisLength) {
          sheets.add(previous.withLength(merged));
          remainingLength = 0;
          break;
        }
      } else {
        sheets.add(_SheetGene(length: length));
        remainingLength -= length;
      }
    }
    while (remainingLength > 0) {
      final materialIndex = run.materialIndex.clamp(
        0,
        depthClass.materials.length - 1,
      );
      final maxLength = depthClass.materials[materialIndex].mainAxisLength;
      var length = min(remainingLength, maxLength);
      if (remainingLength - length > 0 && remainingLength - length < minEdge) {
        length = max(minEdge, remainingLength - minEdge);
      }
      sheets.add(_SheetGene(length: length));
      remainingLength -= length;
    }
    final repaired = _RunGenome(
      depthClassIndex: run.depthClassIndex,
      materialIndex: run.materialIndex.clamp(
        0,
        depthClass.materials.length - 1,
      ),
      depth: run.depth,
      sheets: sheets,
    )..materialClass = depthClass;
    return repaired;
  }

  static _ScoredGenome _selectParent(
    List<_ScoredGenome> population,
    Random random,
  ) {
    final tournamentSize = min(4, population.length);
    var best = population[random.nextInt(population.length)];
    for (var i = 1; i < tournamentSize; i++) {
      final candidate = population[random.nextInt(population.length)];
      if (candidate.fitness < best.fitness) {
        best = candidate;
      }
    }
    return best;
  }

  static int _pickDepthClassIndex(
    List<_MaterialDepthClass> materialClasses,
    Random random,
  ) => random.nextInt(materialClasses.length);

  static int _nearestDepthClassIndex(
    List<_MaterialDepthClass> materialClasses,
    int depth,
  ) {
    var bestIndex = 0;
    var bestDistance = (materialClasses.first.depth - depth).abs();
    for (var i = 1; i < materialClasses.length; i++) {
      final distance = (materialClasses[i].depth - depth).abs();
      if (distance < bestDistance) {
        bestIndex = i;
        bestDistance = distance;
      }
    }
    return bestIndex;
  }

  static int _nearestMaterialIndex(_MaterialDepthClass depthClass, int length) {
    var bestIndex = 0;
    var bestDistance = (depthClass.materials.first.mainAxisLength - length)
        .abs();
    for (var i = 1; i < depthClass.materials.length; i++) {
      final distance = (depthClass.materials[i].mainAxisLength - length).abs();
      if (distance < bestDistance) {
        bestIndex = i;
        bestDistance = distance;
      }
    }
    return bestIndex;
  }

  static int _randomMaterialForLength(
    _MaterialDepthClass depthClass,
    int length,
    Random random,
  ) {
    final viable = <int>[
      for (var i = 0; i < depthClass.materials.length; i++)
        if (depthClass.materials[i].mainAxisLength >= length) i,
    ];
    if (viable.isEmpty) {
      return depthClass.materials.length - 1;
    }
    return viable[random.nextInt(viable.length)];
  }

  static (int, int, int, int) _bounds(List<PlasterRoomLine> lines) {
    var minX = lines.first.startX;
    var maxX = lines.first.startX;
    var minY = lines.first.startY;
    var maxY = lines.first.startY;
    for (final line in lines) {
      minX = min(minX, line.startX);
      maxX = max(maxX, line.startX);
      minY = min(minY, line.startY);
      maxY = max(maxY, line.startY);
    }
    return (minX, minY, maxX, maxY);
  }

  static String _surfaceLabel(
    String name,
    int width,
    int height,
    PreferredUnitSystem unitSystem,
  ) =>
      '$name: ${PlasterGeometry.formatDisplayLength(width, unitSystem)} x '
      '${PlasterGeometry.formatDisplayLength(height, unitSystem)}';

  static int _estimateJointTapeLength(List<PlasterSheetPlacement> placements) {
    var total = 0;
    for (var i = 0; i < placements.length; i++) {
      final left = placements[i];
      for (var j = i + 1; j < placements.length; j++) {
        final right = placements[j];
        if (left.x + left.width == right.x || right.x + right.width == left.x) {
          total += _overlapLength(left.y, left.height, right.y, right.height);
        }
        if (left.y + left.height == right.y ||
            right.y + right.height == left.y) {
          total += _overlapLength(left.x, left.width, right.x, right.width);
        }
      }
    }
    return total;
  }

  static int _staggerViolationCount(PlasterSurfaceLayout layout) {
    final minStagger = PlasterGeometry.minEdgePiece(layout.material.unitSystem);
    final rowsByY = <int, List<PlasterSheetPlacement>>{};
    for (final placement in layout.placements) {
      rowsByY.putIfAbsent(placement.y, () => []).add(placement);
    }
    final orderedRows = rowsByY.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    var violations = 0;
    for (var i = 0; i < orderedRows.length - 1; i++) {
      final upper = _internalVerticalJoints(orderedRows[i].value, layout.width);
      final lower = _internalVerticalJoints(
        orderedRows[i + 1].value,
        layout.width,
      );
      for (final leftJoint in upper) {
        for (final rightJoint in lower) {
          if ((leftJoint - rightJoint).abs() < minStagger) {
            violations++;
          }
        }
      }
    }
    return violations;
  }

  static List<int> _internalVerticalJoints(
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

  static int _overlapLength(int startA, int lengthA, int startB, int lengthB) {
    final overlapStart = max(startA, startB);
    final overlapEnd = min(startA + lengthA, startB + lengthB);
    return max(0, overlapEnd - overlapStart);
  }

  static int _estimateScrews(int area, bool isCeiling) {
    final areaSqM =
        area /
        (PlasterGeometry.metricUnitsPerMm * PlasterGeometry.metricUnitsPerMm) /
        1000000;
    final perHundredSqM = isCeiling ? 820 : 620;
    return max(1, (areaSqM * perHundredSqM / 100).ceil());
  }

  static double _estimateGlueKg(int area, bool isCeiling) {
    if (isCeiling) {
      return 0;
    }
    final areaSqM =
        area /
        (PlasterGeometry.metricUnitsPerMm * PlasterGeometry.metricUnitsPerMm) /
        1000000;
    return areaSqM * 3.5 / 100;
  }

  static double _estimatePlasterKg(int area) {
    final areaSqM =
        area /
        (PlasterGeometry.metricUnitsPerMm * PlasterGeometry.metricUnitsPerMm) /
        1000000;
    return areaSqM * (24 + 8) / 100;
  }
}

class _SurfaceSpec {
  final int index;
  final PlasterRoomShape roomShape;
  final int roomId;
  final int? lineId;
  final bool isCeiling;
  final String label;
  final int width;
  final int height;
  final int area;
  _MaterialDepthClass? fallbackMaterialClass;

  _SurfaceSpec({
    required this.index,
    required this.roomShape,
    required this.roomId,
    required this.lineId,
    required this.isCeiling,
    required this.label,
    required this.width,
    required this.height,
    required this.area,
  });

  PreferredUnitSystem get unitSystem => roomShape.room.unitSystem;
}

class _MaterialOption {
  final PlasterMaterialSize material;
  final int mainAxisLength;
  final int crossAxisDepth;

  const _MaterialOption({
    required this.material,
    required this.mainAxisLength,
    required this.crossAxisDepth,
  });
}

class _MaterialDepthClass {
  final int depth;
  final List<_MaterialOption> materials;

  const _MaterialDepthClass({required this.depth, required this.materials});

  int get maxLength => materials.last.mainAxisLength;

  static List<_MaterialDepthClass> build(List<PlasterMaterialSize> materials) {
    final grouped = <int, List<_MaterialOption>>{};
    for (final material in materials) {
      if (material.excludedFromLayout) {
        continue;
      }
      final shortSide = min(material.width, material.height);
      final longSide = max(material.width, material.height);
      grouped
          .putIfAbsent(shortSide, () => [])
          .add(
            _MaterialOption(
              material: material,
              mainAxisLength: longSide,
              crossAxisDepth: shortSide,
            ),
          );
    }
    final classes = [
      for (final entry in grouped.entries)
        _MaterialDepthClass(
          depth: entry.key,
          materials: entry.value
            ..sort(
              (left, right) =>
                  left.mainAxisLength.compareTo(right.mainAxisLength),
            ),
        ),
    ]..sort((left, right) => left.depth.compareTo(right.depth));
    return classes;
  }
}

class _Genome {
  final List<_SurfaceGenome> surfaces;

  const _Genome(this.surfaces);
}

class _SurfaceGenome {
  final int specIndex;
  final List<_RunGenome> runs;
  _SurfaceSpec? spec;

  _SurfaceGenome({required this.specIndex, required this.runs});

  _SurfaceGenome copy() => _SurfaceGenome(
    specIndex: specIndex,
    runs: [for (final run in runs) run.copy()],
  )..spec = spec;
}

class _RunGenome {
  final int depthClassIndex;
  final int materialIndex;
  final int depth;
  final List<_SheetGene> sheets;
  _MaterialDepthClass? materialClass;

  _RunGenome({
    required this.depthClassIndex,
    required this.materialIndex,
    required this.depth,
    required this.sheets,
  });

  _RunGenome copy() => _RunGenome(
    depthClassIndex: depthClassIndex,
    materialIndex: materialIndex,
    depth: depth,
    sheets: [for (final sheet in sheets) sheet.copy()],
  )..materialClass = materialClass;

  _RunGenome withDepth(int depth) => _RunGenome(
    depthClassIndex: depthClassIndex,
    materialIndex: materialIndex,
    depth: depth,
    sheets: [for (final sheet in sheets) sheet.copy()],
  )..materialClass = materialClass;

  _RunGenome withMaterial({
    required int depthClassIndex,
    required int materialIndex,
  }) => _RunGenome(
    depthClassIndex: depthClassIndex,
    materialIndex: materialIndex,
    depth: depth,
    sheets: [for (final sheet in sheets) sheet.copy()],
  )..materialClass = materialClass;
}

class _SheetGene {
  final int length;

  _SheetGene({required this.length});

  _SheetGene copy() => _SheetGene(length: length);

  _SheetGene withLength(int length) => _SheetGene(length: length);
}

class _ScoredGenome implements Comparable<_ScoredGenome> {
  final _Genome genome;
  final double fitness;

  const _ScoredGenome({required this.genome, required this.fitness});

  @override
  int compareTo(_ScoredGenome other) => fitness.compareTo(other.fitness);
}
