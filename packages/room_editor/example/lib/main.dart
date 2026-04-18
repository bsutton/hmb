import 'package:flutter/material.dart';
import 'package:room_editor/room_editor.dart';

void main() {
  RoomEditorConstraintSolver.debugLoggingEnabled = true;
  runApp(const RoomEditorExampleApp());
}

class RoomEditorExampleApp extends StatelessWidget {
  const RoomEditorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Room Editor Browser Harness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E7490),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101418),
      ),
      home: const _RoomEditorHarnessScreen(),
    );
  }
}

class _RoomEditorHarnessScreen extends StatefulWidget {
  const _RoomEditorHarnessScreen();

  @override
  State<_RoomEditorHarnessScreen> createState() =>
      _RoomEditorHarnessScreenState();
}

class _RoomEditorHarnessScreenState extends State<_RoomEditorHarnessScreen> {
  RoomEditorDocument _document = _initialDocument;
  late Set<int> _includedLineIds;

  @override
  void initState() {
    super.initState();
    _includedLineIds = {
      for (final line in _document.bundle.lines) line.id,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Editor Browser Harness'),
        backgroundColor: const Color(0xFF16202A),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF16202A),
            child: Text(
              'Drag vertices in the browser and inspect the console for '
              '[room_drag] and [room_solver] logs.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: RoomEditorWorkspace(
                      document: _document,
                      editorOnly: true,
                      customTools: _customTools(),
                      linePresentations: _linePresentations(),
                      onDocumentCommitted: (document) {
                        setState(() {
                          _document = document;
                          _includedLineIds = _syncIncludedLineIds(document);
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xFF16202A),
                      border: Border(
                        left: BorderSide(color: Color(0xFF223040)),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DefaultTextStyle(
                        style: theme.textTheme.bodySmall!,
                        child: ListView(
                          children: [
                            Text(
                              'Current geometry',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            for (
                              var i = 0;
                              i < _document.bundle.lines.length;
                              i++
                            )
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(_describeLine(i)),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              'Constraints',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            for (final constraint in _document.constraints)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(_describeConstraint(constraint)),
                              ),
                          ],
                        ),
                      ),
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

  String _describeLine(int index) {
    final line = _document.bundle.lines[index];
    final end = RoomCanvasGeometry.lineEnd(_document.bundle.lines, index);
    final included = _includedLineIds.contains(line.id) ? 'included' : 'excluded';
    return 'W${index + 1} '
        'start=(${line.startX}, ${line.startY}) '
        'end=(${end.x}, ${end.y}) '
        'length=${line.length} '
        '[$included]';
  }

  Set<int> _syncIncludedLineIds(RoomEditorDocument document) {
    final previousIds = {
      for (final line in _document.bundle.lines) line.id,
    };
    return {
      for (final line in document.bundle.lines)
        if (_includedLineIds.contains(line.id) || !previousIds.contains(line.id))
          line.id,
    };
  }

  Map<int, RoomEditorLinePresentation> _linePresentations() => {
    for (final line in _document.bundle.lines)
      if (!_includedLineIds.contains(line.id))
        line.id: const RoomEditorLinePresentation(
          style: RoomEditorLineStrokeStyle.dashed,
        ),
  };

  List<RoomEditorCustomTool> _customTools() => [
    RoomEditorCustomTool(
      id: 'toggle-layout-inclusion',
      label: 'Layout',
      helpText: 'Toggle whether the selected wall is to be plastered.',
      icon: Icons.layers_outlined,
      selectionRule: RoomEditorCustomToolSelectionRule.oneOrMoreLines,
      isSelected: (context) =>
          context.selection.selectedLineIndices.isNotEmpty &&
          context.selection.selectedLineIndices.every(
            (index) => _includedLineIds.contains(_document.bundle.lines[index].id),
          ),
      onInvoked: (invocation) async {
        final include = invocation.selection.selectedLineIndices.any(
          (index) => !_includedLineIds.contains(_document.bundle.lines[index].id),
        );
        setState(() {
          for (final index in invocation.selection.selectedLineIndices) {
            final lineId = _document.bundle.lines[index].id;
            if (include) {
              _includedLineIds.add(lineId);
            } else {
              _includedLineIds.remove(lineId);
            }
          }
        });
      },
    ),
  ];

  String _describeConstraint(RoomEditorConstraint constraint) {
    final ownerIndex = _document.bundle.lines.indexWhere(
      (line) => line.id == constraint.lineId,
    );
    final ownerLabel = ownerIndex == -1
        ? 'wall ${constraint.lineId}'
        : 'W${ownerIndex + 1}';
    final targetLabel = constraint.type == RoomEditorConstraintType.parallel
        ? _describeParallelTarget(constraint.targetValue)
        : constraint.targetValue?.toString();
    final suffix = targetLabel == null || targetLabel.isEmpty
        ? ''
        : ' $targetLabel';
    return '$ownerLabel: ${constraint.type.name}$suffix';
  }

  String? _describeParallelTarget(int? targetLineId) {
    if (targetLineId == null) {
      return null;
    }
    final targetIndex = _document.bundle.lines.indexWhere(
      (line) => line.id == targetLineId,
    );
    return targetIndex == -1 ? 'wall $targetLineId' : 'W${targetIndex + 1}';
  }
}

final RoomEditorDocument _initialDocument = RoomEditorDocument(
  bundle: buildRoomEditorBundle(
    roomName: 'Debug Room',
    unitSystem: RoomEditorUnitSystem.metric,
    plasterCeiling: true,
    lines: const [
      (
        id: 1,
        seqNo: 1,
        startX: 0,
        startY: 0,
        length: 3600
      ),
      (
        id: 2,
        seqNo: 2,
        startX: 3600,
        startY: 0,
        length: 2400
      ),
      (
        id: 3,
        seqNo: 3,
        startX: 3600,
        startY: 2400,
        length: 1800
      ),
      (
        id: 4,
        seqNo: 4,
        startX: 1800,
        startY: 2400,
        length: 1200
      ),
      (
        id: 5,
        seqNo: 5,
        startX: 1800,
        startY: 1200,
        length: 1800
      ),
      (
        id: 6,
        seqNo: 6,
        startX: 0,
        startY: 1200,
        length: 1200
      ),
    ],
    openings: const [],
  ),
  constraints: const [
    RoomEditorConstraint(lineId: 1, type: RoomEditorConstraintType.horizontal),
    RoomEditorConstraint(
      lineId: 1,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 3600,
    ),
    RoomEditorConstraint(lineId: 2, type: RoomEditorConstraintType.vertical),
    RoomEditorConstraint(
      lineId: 2,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 2400,
    ),
    RoomEditorConstraint(lineId: 3, type: RoomEditorConstraintType.horizontal),
    RoomEditorConstraint(
      lineId: 3,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 1800,
    ),
    RoomEditorConstraint(lineId: 4, type: RoomEditorConstraintType.vertical),
    RoomEditorConstraint(
      lineId: 4,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 1200,
    ),
    RoomEditorConstraint(lineId: 5, type: RoomEditorConstraintType.horizontal),
    RoomEditorConstraint(
      lineId: 5,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 1800,
    ),
    RoomEditorConstraint(lineId: 6, type: RoomEditorConstraintType.vertical),
    RoomEditorConstraint(
      lineId: 6,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 1200,
    ),
    RoomEditorConstraint(
      lineId: 1,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
    RoomEditorConstraint(
      lineId: 2,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
    RoomEditorConstraint(
      lineId: 3,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
    RoomEditorConstraint(
      lineId: 4,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
    RoomEditorConstraint(
      lineId: 5,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
    RoomEditorConstraint(
      lineId: 6,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
  ],
);
