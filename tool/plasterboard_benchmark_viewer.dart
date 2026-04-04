// ignore_for_file: do_not_use_environment

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:plasterboard_explorer/plasterboard_explorer.dart';

import '../test/util/plaster_solver_benchmark_support.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final leftSnapshot = await _loadConfiguredSnapshot(
    filePath: const String.fromEnvironment('LEFT_SNAPSHOT'),
    fallbackSolverFamily: 'live_solver',
  );
  final rightSnapshot = await _loadConfiguredSnapshot(
    filePath: const String.fromEnvironment('RIGHT_SNAPSHOT'),
    fallbackSolverFamily: 'live_solver',
  );

  runApp(
    _BenchmarkViewerApp(
      leftSnapshot: leftSnapshot,
      rightSnapshot: rightSnapshot,
    ),
  );
}

Future<BenchmarkVisualSnapshotSet> _loadConfiguredSnapshot({
  required String filePath,
  required String fallbackSolverFamily,
}) async {
  if (filePath.trim().isEmpty) {
    return _buildLiveSnapshotSet(fallbackSolverFamily);
  }

  final file = File(filePath);
  final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  return BenchmarkVisualSnapshotSet.fromJson(json);
}

BenchmarkVisualSnapshotSet _buildLiveSnapshotSet(String solverFamily) {
  final corpus = loadPlasterSolverBenchmarkCorpus();
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

  return BenchmarkVisualSnapshotSet(
    schemaVersion: corpus.schemaVersion,
    scoringVersion: corpus.scoringVersion,
    solverFamily: solverFamily,
    scenarios: [
      for (final scenario in corpus.scenarios)
        calculateBenchmarkVisualSnapshot(scenario, materials),
    ],
  );
}

class _BenchmarkViewerApp extends StatelessWidget {
  final BenchmarkVisualSnapshotSet leftSnapshot;
  final BenchmarkVisualSnapshotSet rightSnapshot;

  const _BenchmarkViewerApp({
    required this.leftSnapshot,
    required this.rightSnapshot,
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: _BenchmarkViewerScreen(
      leftSnapshot: leftSnapshot,
      rightSnapshot: rightSnapshot,
    ),
  );
}

class _BenchmarkViewerScreen extends StatefulWidget {
  final BenchmarkVisualSnapshotSet leftSnapshot;
  final BenchmarkVisualSnapshotSet rightSnapshot;

  const _BenchmarkViewerScreen({
    required this.leftSnapshot,
    required this.rightSnapshot,
  });

  @override
  State<_BenchmarkViewerScreen> createState() => _BenchmarkViewerScreenState();
}

class _BenchmarkViewerScreenState extends State<_BenchmarkViewerScreen> {
  late String _selectedScenarioId;

  @override
  void initState() {
    super.initState();
    _selectedScenarioId = _scenarioIds.first;
  }

  List<String> get _scenarioIds {
    final ids = <String>{
      ...widget.leftSnapshot.scenariosById.keys,
      ...widget.rightSnapshot.scenariosById.keys,
    }.toList()..sort();
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final leftScenario = widget.leftSnapshot.scenariosById[_selectedScenarioId];
    final rightScenario =
        widget.rightSnapshot.scenariosById[_selectedScenarioId];
    final scenarioName =
        leftScenario?.scenarioName ?? rightScenario?.scenarioName ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Plasterboard Benchmark Viewer')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedScenarioId,
                    decoration: const InputDecoration(
                      labelText: 'Scenario',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final id in _scenarioIds)
                        DropdownMenuItem(
                          value: id,
                          child: Text(
                            widget
                                    .leftSnapshot
                                    .scenariosById[id]
                                    ?.scenarioName ??
                                widget
                                    .rightSnapshot
                                    .scenariosById[id]
                                    ?.scenarioName ??
                                id,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _selectedScenarioId = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    scenarioName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
                    child: leftScenario == null
                        ? _MissingScenarioPane(
                            solverFamily: widget.leftSnapshot.solverFamily,
                          )
                        : BenchmarkSheetExplorerPane(
                            solverFamily: widget.leftSnapshot.solverFamily,
                            scenario: leftScenario,
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
                    child: rightScenario == null
                        ? _MissingScenarioPane(
                            solverFamily: widget.rightSnapshot.solverFamily,
                          )
                        : BenchmarkSheetExplorerPane(
                            solverFamily: widget.rightSnapshot.solverFamily,
                            scenario: rightScenario,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingScenarioPane extends StatelessWidget {
  final String solverFamily;

  const _MissingScenarioPane({required this.solverFamily});

  @override
  Widget build(BuildContext context) => Card(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('$solverFamily has no snapshot for this scenario.'),
      ),
    ),
  );
}
