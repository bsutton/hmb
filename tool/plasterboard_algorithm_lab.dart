// ignore_for_file: do_not_use_environment

import 'package:flutter/material.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';
import 'package:hmb/util/dart/plaster_layout_scoring.dart';
import 'package:plasterboard_explorer/plasterboard_explorer.dart';

import '../test/util/plaster_solver_benchmark_support.dart';
import 'plasterboard_genetic_solver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _PlasterboardAlgorithmLabApp());
}

class _PlasterboardAlgorithmLabApp extends StatelessWidget {
  const _PlasterboardAlgorithmLabApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const _PlasterboardAlgorithmLabScreen(),
  );
}

class _PlasterboardAlgorithmLabScreen extends StatefulWidget {
  const _PlasterboardAlgorithmLabScreen();

  @override
  State<_PlasterboardAlgorithmLabScreen> createState() =>
      _PlasterboardAlgorithmLabScreenState();
}

class _PlasterboardAlgorithmLabScreenState
    extends State<_PlasterboardAlgorithmLabScreen> {
  late final SolverBenchmarkCorpus _corpus;
  late final List<PlasterMaterialSize> _materials;
  late String _scenarioId;
  var _leftAlgorithmId = _algorithms.first.id;
  var _rightAlgorithmId = 'genetic_waste';
  final _runs = <String, _AlgorithmRun>{};

  @override
  void initState() {
    super.initState();
    _corpus = loadPlasterSolverBenchmarkCorpus();
    _materials = _defaultMaterials();
    _scenarioId = _corpus.scenarios.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _corpus.scenarios.firstWhere(
      (scenario) => scenario.id == _scenarioId,
    );
    final leftAlgorithm = _algorithmById(_leftAlgorithmId);
    final rightAlgorithm = _algorithmById(_rightAlgorithmId);
    final leftRun = _run(scenario, leftAlgorithm);
    final rightRun = _run(scenario, rightAlgorithm);

    return Scaffold(
      appBar: AppBar(title: const Text('Plasterboard Algorithm Lab')),
      body: Column(
        children: [
          _LabControls(
            corpus: _corpus,
            scenarioId: _scenarioId,
            leftAlgorithmId: _leftAlgorithmId,
            rightAlgorithmId: _rightAlgorithmId,
            onScenarioChanged: (value) {
              setState(() => _scenarioId = value);
            },
            onLeftAlgorithmChanged: (value) {
              setState(() => _leftAlgorithmId = value);
            },
            onRightAlgorithmChanged: (value) {
              setState(() => _rightAlgorithmId = value);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _ScenarioSummary(
              scenario: scenario,
              leftRun: leftRun,
              rightRun: rightRun,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _VisualComparisonBand(leftRun: leftRun, rightRun: rightRun),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
                    child: _AlgorithmPane(run: leftRun),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
                    child: _AlgorithmPane(run: rightRun),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _AlgorithmRun _run(
    SolverBenchmarkScenario scenario,
    _AlgorithmDefinition algorithm,
  ) {
    final cacheKey = '${scenario.id}:${algorithm.id}';
    return _runs.putIfAbsent(
      cacheKey,
      () => algorithm.run(
        scenario: scenario,
        corpus: _corpus,
        materials: _materials,
      ),
    );
  }
}

class _LabControls extends StatelessWidget {
  final SolverBenchmarkCorpus corpus;
  final String scenarioId;
  final String leftAlgorithmId;
  final String rightAlgorithmId;
  final ValueChanged<String> onScenarioChanged;
  final ValueChanged<String> onLeftAlgorithmChanged;
  final ValueChanged<String> onRightAlgorithmChanged;

  const _LabControls({
    required this.corpus,
    required this.scenarioId,
    required this.leftAlgorithmId,
    required this.rightAlgorithmId,
    required this.onScenarioChanged,
    required this.onLeftAlgorithmChanged,
    required this.onRightAlgorithmChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            initialValue: scenarioId,
            decoration: const InputDecoration(
              labelText: 'Fixture',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final scenario in corpus.scenarios)
                DropdownMenuItem(
                  value: scenario.id,
                  child: Text(scenario.name),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onScenarioChanged(value);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AlgorithmDropdown(
            label: 'Left algorithm',
            value: leftAlgorithmId,
            onChanged: onLeftAlgorithmChanged,
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Swap algorithms',
          icon: const Icon(Icons.swap_horiz),
          onPressed: () {
            onLeftAlgorithmChanged(rightAlgorithmId);
            onRightAlgorithmChanged(leftAlgorithmId);
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AlgorithmDropdown(
            label: 'Right algorithm',
            value: rightAlgorithmId,
            onChanged: onRightAlgorithmChanged,
          ),
        ),
      ],
    ),
  );
}

class _AlgorithmDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _AlgorithmDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final algorithm in _algorithms)
        DropdownMenuItem(value: algorithm.id, child: Text(algorithm.name)),
    ],
    onChanged: (value) {
      if (value != null) {
        onChanged(value);
      }
    },
  );
}

class _ScenarioSummary extends StatelessWidget {
  final SolverBenchmarkScenario scenario;
  final _AlgorithmRun leftRun;
  final _AlgorithmRun rightRun;

  const _ScenarioSummary({
    required this.scenario,
    required this.leftRun,
    required this.rightRun,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          scenario.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      _MetricDelta(
        label: 'Sheets',
        left: leftRun.result.takeoff.totalSheetCount.toDouble(),
        right: rightRun.result.takeoff.totalSheetCount.toDouble(),
        decimals: 0,
      ),
      const SizedBox(width: 16),
      _MetricDelta(
        label: 'Waste',
        left: leftRun.result.takeoff.estimatedWastePercent,
        right: rightRun.result.takeoff.estimatedWastePercent,
        suffix: '%',
      ),
      const SizedBox(width: 16),
      _MetricDelta(
        label: 'Tape',
        left: leftRun.result.layouts.fold<double>(
          0,
          (sum, layout) => sum + layout.estimatedJointTapeLength,
        ),
        right: rightRun.result.layouts.fold<double>(
          0,
          (sum, layout) => sum + layout.estimatedJointTapeLength,
        ),
        formatter: _formatMeters,
      ),
    ],
  );
}

class _MetricDelta extends StatelessWidget {
  final String label;
  final double left;
  final double right;
  final int decimals;
  final String suffix;
  final String Function(double value)? formatter;

  const _MetricDelta({
    required this.label,
    required this.left,
    required this.right,
    this.decimals = 1,
    this.suffix = '',
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final difference = right - left;
    final format = formatter ?? (value) => value.toStringAsFixed(decimals);
    final delta = difference == 0
        ? 'same'
        : '${difference > 0 ? '+' : ''}${format(difference)}$suffix';
    return Text(
      '$label ${format(left)}$suffix / ${format(right)}$suffix '
      '($delta)',
    );
  }
}

class _VisualComparisonBand extends StatelessWidget {
  final _AlgorithmRun leftRun;
  final _AlgorithmRun rightRun;

  const _VisualComparisonBand({required this.leftRun, required this.rightRun});

  @override
  Widget build(BuildContext context) {
    final leftTape = leftRun.snapshot.jointTapeLength.toDouble();
    final rightTape = rightRun.snapshot.jointTapeLength.toDouble();
    final leftWaste = leftRun.result.takeoff.estimatedWastePercent;
    final rightWaste = rightRun.result.takeoff.estimatedWastePercent;
    final leftSheets = leftRun.result.takeoff.totalSheetCount.toDouble();
    final rightSheets = rightRun.result.takeoff.totalSheetCount.toDouble();
    final leftMs = leftRun.result.elapsedMs.toDouble();
    final rightMs = rightRun.result.elapsedMs.toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        children: [
          _ComparisonBar(
            label: 'Waste',
            leftName: leftRun.algorithm.name,
            rightName: rightRun.algorithm.name,
            leftValue: leftWaste,
            rightValue: rightWaste,
            valueLabel: (value) => '${value.toStringAsFixed(1)}%',
            lowerIsBetter: true,
          ),
          _ComparisonBar(
            label: 'Sheets',
            leftName: leftRun.algorithm.name,
            rightName: rightRun.algorithm.name,
            leftValue: leftSheets,
            rightValue: rightSheets,
            valueLabel: (value) => value.toStringAsFixed(0),
            lowerIsBetter: true,
          ),
          _ComparisonBar(
            label: 'Tape',
            leftName: leftRun.algorithm.name,
            rightName: rightRun.algorithm.name,
            leftValue: leftTape,
            rightValue: rightTape,
            valueLabel: _formatMeters,
            lowerIsBetter: true,
          ),
          _ComparisonBar(
            label: 'Runtime',
            leftName: leftRun.algorithm.name,
            rightName: rightRun.algorithm.name,
            leftValue: leftMs,
            rightValue: rightMs,
            valueLabel: (value) => '${value.toStringAsFixed(0)} ms',
            lowerIsBetter: true,
          ),
        ],
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  final String label;
  final String leftName;
  final String rightName;
  final double leftValue;
  final double rightValue;
  final String Function(num value) valueLabel;
  final bool lowerIsBetter;

  const _ComparisonBar({
    required this.label,
    required this.leftName,
    required this.rightName,
    required this.leftValue,
    required this.rightValue,
    required this.valueLabel,
    required this.lowerIsBetter,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = [
      leftValue,
      rightValue,
      1.0,
    ].reduce((a, b) => a > b ? a : b);
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          _MetricBarRow(
            name: leftName,
            value: leftValue,
            maxValue: maxValue,
            valueLabel: valueLabel,
            isWinner: _isWinner(leftValue, rightValue),
          ),
          const SizedBox(height: 4),
          _MetricBarRow(
            name: rightName,
            value: rightValue,
            maxValue: maxValue,
            valueLabel: valueLabel,
            isWinner: _isWinner(rightValue, leftValue),
          ),
        ],
      ),
    );
  }

  bool _isWinner(double value, double other) =>
      lowerIsBetter ? value < other : value > other;
}

class _MetricBarRow extends StatelessWidget {
  final String name;
  final double value;
  final double maxValue;
  final String Function(num value) valueLabel;
  final bool isWinner;

  const _MetricBarRow({
    required this.name,
    required this.value,
    required this.maxValue,
    required this.valueLabel,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWinner
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.primary;
    final factor = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: factor,
              minHeight: 8,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            valueLabel(value),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _AlgorithmPane extends StatelessWidget {
  final _AlgorithmRun run;

  const _AlgorithmPane({required this.run});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _AlgorithmRunHeader(run: run),
      ),
      Expanded(
        child: BenchmarkSheetExplorerPane(
          solverFamily: run.algorithm.name,
          scenario: run.snapshot,
        ),
      ),
    ],
  );
}

class _AlgorithmRunHeader extends StatelessWidget {
  final _AlgorithmRun run;

  const _AlgorithmRunHeader({required this.run});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(run.algorithm.name, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(run.algorithm.description),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            Text('${run.result.takeoff.totalSheetCount} sheets'),
            Text(
              '${run.result.takeoff.estimatedWastePercent.toStringAsFixed(1)}'
              '% waste',
            ),
            Text('${_formatMeters(run.snapshot.jointTapeLength)} tape'),
            Text('${run.result.exploredStates} states'),
            Text('${run.result.elapsedMs} ms'),
          ],
        ),
      ],
    ),
  );
}

class _AlgorithmDefinition {
  final String id;
  final String name;
  final String description;
  final PlasterLayoutScoring scoring;
  final GeneticPlasterSolverConfig? geneticConfig;
  final int maxDurationMs;

  const _AlgorithmDefinition({
    required this.id,
    required this.name,
    required this.description,
    this.scoring = const PlasterLayoutScoring.defaults(),
    this.geneticConfig,
    this.maxDurationMs = 300000,
  });

  _AlgorithmRun run({
    required SolverBenchmarkScenario scenario,
    required SolverBenchmarkCorpus corpus,
    required List<PlasterMaterialSize> materials,
  }) {
    final result = geneticConfig == null
        ? PlasterGeometry.analyzeProject(
            PlasterAnalysisRequest(
              roomShapes: scenario.shapes,
              materials: materials,
              wastePercent: 0,
              scoring: scoring,
              maxDurationMs: maxDurationMs,
            ),
          )
        : _runGeneticSolver(scenario, materials, geneticConfig!);
    final sheets = PlasterGeometry.buildProjectSheetExplorer(
      scenario.shapes,
      result.layouts,
    );
    final snapshot = buildBenchmarkVisualScenarioSnapshot(
      scenarioId: scenario.id,
      scenarioName: scenario.name,
      layouts: result.layouts,
      sheets: sheets,
      takeoff: result.takeoff,
    );
    return _AlgorithmRun(
      algorithm: this,
      scenario: scenario,
      result: result,
      snapshot: snapshot,
    );
  }
}

PlasterAnalysisResult _runGeneticSolver(
  SolverBenchmarkScenario scenario,
  List<PlasterMaterialSize> materials,
  GeneticPlasterSolverConfig config,
) {
  final result = GeneticPlasterSolver.solve(
    roomShapes: scenario.shapes,
    materials: materials,
    config: config,
  );
  return PlasterAnalysisResult(
    layouts: result.layouts,
    takeoff: result.takeoff,
    exploredStates: result.evaluatedCandidates,
    elapsedMs: result.elapsedMs,
    complete: true,
    timedOut: false,
    reachedTargetWaste: result.takeoff.estimatedWastePercent <= 1,
  );
}

class _AlgorithmRun {
  final _AlgorithmDefinition algorithm;
  final SolverBenchmarkScenario scenario;
  final PlasterAnalysisResult result;
  final BenchmarkVisualScenarioSnapshot snapshot;

  const _AlgorithmRun({
    required this.algorithm,
    required this.scenario,
    required this.result,
    required this.snapshot,
  });
}

_AlgorithmDefinition _algorithmById(String id) =>
    _algorithms.firstWhere((algorithm) => algorithm.id == id);

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

String _formatMeters(num value) => '${(value / 10000).toStringAsFixed(2)} m';

const _algorithms = [
  _AlgorithmDefinition(
    id: 'balanced_beam',
    name: 'Balanced beam',
    description: 'Current production scoring profile.',
  ),
  _AlgorithmDefinition(
    id: 'sheet_minimiser',
    name: 'Sheet minimiser',
    description: 'Prioritises the lowest purchased sheet count.',
    scoring: PlasterLayoutScoring(
      extraSheetWeight: 2000000,
      jointLengthWeight: 1,
      buttJointWeight: 20,
      cutPieceWeight: 1200,
      highJointWeight: 2,
      smallPieceWeight: 2500,
      fragmentationWeight: 1,
      verticalWallPenaltyWeight: 200000,
    ),
  ),
  _AlgorithmDefinition(
    id: 'joint_reducer',
    name: 'Joint reducer',
    description: 'Penalises total joints and butt joints more heavily.',
    scoring: PlasterLayoutScoring(
      extraSheetWeight: 850000,
      jointLengthWeight: 8,
      buttJointWeight: 120,
      cutPieceWeight: 2500,
      highJointWeight: 10,
      smallPieceWeight: 6000,
      fragmentationWeight: 1,
      verticalWallPenaltyWeight: 400000,
    ),
  ),
  _AlgorithmDefinition(
    id: 'cut_piece_reducer',
    name: 'Cut-piece reducer',
    description: 'Favours larger, simpler pieces over fine-grained packing.',
    scoring: PlasterLayoutScoring(
      extraSheetWeight: 900000,
      jointLengthWeight: 1,
      buttJointWeight: 40,
      cutPieceWeight: 12000,
      highJointWeight: 4,
      smallPieceWeight: 18000,
      fragmentationWeight: 4,
      verticalWallPenaltyWeight: 400000,
    ),
  ),
  _AlgorithmDefinition(
    id: 'vertical_friendly',
    name: 'Vertical friendly',
    description: 'Reduces the extra penalty for valid vertical wall layouts.',
    scoring: PlasterLayoutScoring(
      extraSheetWeight: 1000000,
      jointLengthWeight: 1,
      buttJointWeight: 40,
      cutPieceWeight: 2500,
      highJointWeight: 4,
      smallPieceWeight: 6000,
      fragmentationWeight: 1,
      verticalWallPenaltyWeight: 20000,
    ),
  ),
  _AlgorithmDefinition(
    id: 'genetic_waste',
    name: 'Genetic waste search',
    description: 'Run-level genetic search tuned for lower cut waste.',
    geneticConfig: GeneticPlasterSolverConfig(
      populationSize: 56,
      generations: 70,
      eliteCount: 8,
      mutationRate: 0.24,
    ),
  ),
  _AlgorithmDefinition(
    id: 'fast_preview',
    name: 'Fast preview',
    description: 'Uses production scoring with a short search budget.',
    maxDurationMs: 1200,
  ),
];
