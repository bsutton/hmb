import 'package:flutter_test/flutter_test.dart';
import 'package:room_editor/room_editor.dart';

void main() {
  test('includes requested constraint alongside top solver conflicts', () {
    const requestedKey = RoomEditorConstraintKey(
      lineId: 9,
      type: RoomEditorConstraintType.parallel,
    );
    final keys = deriveConstraintConflictHighlightKeys(
      requestedConstraintKeys: {requestedKey},
      solverViolations: [
        _violation(1, RoomEditorConstraintType.horizontal, 20),
        _violation(2, RoomEditorConstraintType.vertical, 10),
      ],
    );

    expect(keys, contains(requestedKey));
    expect(
      keys,
      contains(
        const RoomEditorConstraintKey(
          lineId: 1,
          type: RoomEditorConstraintType.horizontal,
        ),
      ),
    );
    expect(
      keys,
      contains(
        const RoomEditorConstraintKey(
          lineId: 2,
          type: RoomEditorConstraintType.vertical,
        ),
      ),
    );
  });

  test('deduplicates requested constraint when solver reports same key', () {
    const requestedKey = RoomEditorConstraintKey(
      lineId: 1,
      type: RoomEditorConstraintType.horizontal,
    );
    final keys = deriveConstraintConflictHighlightKeys(
      requestedConstraintKeys: {requestedKey},
      solverViolations: [
        _violation(1, RoomEditorConstraintType.horizontal, 20),
        _violation(2, RoomEditorConstraintType.vertical, 10),
      ],
    );

    expect(keys.length, 2);
    expect(keys, contains(requestedKey));
    expect(
      keys,
      contains(
        const RoomEditorConstraintKey(
          lineId: 2,
          type: RoomEditorConstraintType.vertical,
        ),
      ),
    );
  });

  test('parallel target selection rejects adjacent lines', () {
    expect(
      parallelTargetLinesForSelection(
        selectedLineIndices: {0, 1},
        lineCount: 4,
      ),
      isNull,
    );
    expect(
      parallelTargetLinesForSelection(
        selectedLineIndices: {0, 3},
        lineCount: 4,
      ),
      isNull,
    );
  });

  test('horizontal can be applied to one wall of a parallel pair', () {
    final lines = <RoomEditorLine>[
      const RoomEditorLine(
        id: 1,
        seqNo: 1,
        startX: 137,
        startY: -954,
        length: 2863,
        plasterSelected: true,
      ),
      const RoomEditorLine(
        id: 2,
        seqNo: 2,
        startX: 3000,
        startY: -954,
        length: 3407,
        plasterSelected: true,
      ),
      const RoomEditorLine(
        id: 3,
        seqNo: 3,
        startX: 3600,
        startY: 2400,
        length: 3795,
        plasterSelected: true,
      ),
      const RoomEditorLine(
        id: 6,
        seqNo: 4,
        startX: 0,
        startY: 1200,
        length: 2160,
        plasterSelected: true,
      ),
    ];
    const constraints = [
      RoomEditorConstraint(
        lineId: 1,
        type: RoomEditorConstraintType.parallel,
        targetValue: 3,
      ),
      RoomEditorConstraint(
        lineId: 1,
        type: RoomEditorConstraintType.horizontal,
      ),
    ];

    final startPinned = RoomEditorConstraintSolver.solve(
      lines: lines,
      constraints: constraints,
      pinnedVertexIndex: 0,
      pinnedVertexTarget: const RoomEditorIntPoint(137, -954),
    );
    final endPinned = RoomEditorConstraintSolver.solve(
      lines: [
        lines[0].copyWith(startY: 0),
        lines[1].copyWith(startY: 0),
        lines[2],
        lines[3].copyWith(startY: 0),
      ],
      constraints: constraints,
      pinnedVertexIndex: 1,
      pinnedVertexTarget: const RoomEditorIntPoint(3000, 0),
    );

    expect(startPinned.converged, isTrue);
    expect(endPinned.converged, isTrue);
    final startPinnedLine1End = RoomCanvasGeometry.lineEnd(
      startPinned.lines,
      0,
    );
    final startPinnedLine3End = RoomCanvasGeometry.lineEnd(
      startPinned.lines,
      2,
    );
    expect(
      startPinned.lines[0].startY,
      closeTo(startPinnedLine1End.y.toDouble(), 0.1),
    );
    expect(
      startPinned.lines[2].startY,
      closeTo(startPinnedLine3End.y.toDouble(), 2),
    );
    final endPinnedLine1End = RoomCanvasGeometry.lineEnd(endPinned.lines, 0);
    final endPinnedLine3End = RoomCanvasGeometry.lineEnd(endPinned.lines, 2);
    expect(
      endPinned.lines[0].startY,
      closeTo(endPinnedLine1End.y.toDouble(), 0.1),
    );
    expect(
      endPinned.lines[2].startY,
      closeTo(endPinnedLine3End.y.toDouble(), 2),
    );
  });

  test('existing parallel constraint is found in either direction', () {
    final lines = <RoomEditorLine>[
      const RoomEditorLine(
        id: 10,
        seqNo: 1,
        startX: 0,
        startY: 0,
        length: 10,
        plasterSelected: true,
      ),
      const RoomEditorLine(
        id: 20,
        seqNo: 2,
        startX: 10,
        startY: 0,
        length: 10,
        plasterSelected: true,
      ),
    ];

    expect(
      existingParallelConstraintForPair(
        pair: (first: 0, second: 1),
        lines: lines,
        constraints: const [
          RoomEditorConstraint(
            lineId: 10,
            type: RoomEditorConstraintType.parallel,
            targetValue: 20,
          ),
        ],
      ),
      isNotNull,
    );
    expect(
      existingParallelConstraintForPair(
        pair: (first: 0, second: 1),
        lines: lines,
        constraints: const [
          RoomEditorConstraint(
            lineId: 20,
            type: RoomEditorConstraintType.parallel,
            targetValue: 10,
          ),
        ],
      ),
      isNotNull,
    );
  });

  test('parallel direction constrains the less-constrained wall', () {
    final lines = <RoomEditorLine>[
      const RoomEditorLine(
        id: 10,
        seqNo: 1,
        startX: 0,
        startY: 0,
        length: 10,
        plasterSelected: true,
      ),
      const RoomEditorLine(
        id: 20,
        seqNo: 2,
        startX: 10,
        startY: 0,
        length: 10,
        plasterSelected: true,
      ),
    ];
    final direction = chooseParallelConstraintDirection(
      pair: (first: 0, second: 1),
      lines: lines,
      constraints: const [
        RoomEditorConstraint(
          lineId: 10,
          type: RoomEditorConstraintType.horizontal,
        ),
        RoomEditorConstraint(
          lineId: 10,
          type: RoomEditorConstraintType.lineLength,
          targetValue: 10,
        ),
      ],
    );

    expect(direction, (source: 1, target: 0));
  });

  test('parallel target selection allows non-adjacent lines', () {
    expect(
      parallelTargetLinesForSelection(
        selectedLineIndices: {0, 2},
        lineCount: 4,
      ),
      (first: 0, second: 2),
    );
  });

  test(
    'detects implicit adjacent wall-length conflicts for a moved corner',
    () {
      final source = RoomEditorDocument(
        bundle: RoomEditorBundle(
          roomName: 'Test',
          unitSystem: RoomEditorUnitSystem.metric,
          plasterCeiling: false,
          lines: [
            const RoomEditorLine(
              id: 1,
              seqNo: 1,
              startX: 0,
              startY: 0,
              length: 100,
              plasterSelected: true,
            ),
            const RoomEditorLine(
              id: 2,
              seqNo: 2,
              startX: 100,
              startY: 0,
              length: 50,
              plasterSelected: true,
            ),
            const RoomEditorLine(
              id: 3,
              seqNo: 3,
              startX: 100,
              startY: 50,
              length: 100,
              plasterSelected: true,
            ),
            const RoomEditorLine(
              id: 4,
              seqNo: 4,
              startX: 0,
              startY: 50,
              length: 50,
              plasterSelected: true,
            ),
          ],
          openings: const [],
        ),
        constraints: const [],
      );
      final attempted = source.copyWith(
        bundle: source.bundle.copyWith(
          lines: [
            ...source.bundle.lines.take(2),
            source.bundle.lines[2].copyWith(startX: 100, startY: 70),
            source.bundle.lines[3],
          ],
        ),
      );

      expect(
        deriveImplicitLengthConflictLineIndices(
          sourceDocument: source,
          attemptedDocument: attempted,
          movedVertexIndex: 2,
        ),
        {1, 2},
      );
    },
  );

  test(
    'filters implicit length conflicts to explicit line-length constraints',
    () {
      final lines = <RoomEditorLine>[
        const RoomEditorLine(
          id: 1,
          seqNo: 1,
          startX: 0,
          startY: 0,
          length: 100,
          plasterSelected: true,
        ),
        const RoomEditorLine(
          id: 2,
          seqNo: 2,
          startX: 100,
          startY: 0,
          length: 50,
          plasterSelected: true,
        ),
        const RoomEditorLine(
          id: 3,
          seqNo: 3,
          startX: 100,
          startY: 50,
          length: 100,
          plasterSelected: true,
        ),
      ];

      expect(
        filterImplicitLengthConflictLineIndices(
          lineIndices: {1, 2},
          lines: lines,
          constraints: const [
            RoomEditorConstraint(
              lineId: 3,
              type: RoomEditorConstraintType.lineLength,
              targetValue: 100,
            ),
          ],
        ),
        {2},
      );
    },
  );

  test(
    'ignores implicit length conflicts when the moved corner is unchanged',
    () {
      final source = RoomEditorDocument(
        bundle: RoomEditorBundle(
          roomName: 'Test',
          unitSystem: RoomEditorUnitSystem.metric,
          plasterCeiling: false,
          lines: [
            const RoomEditorLine(
              id: 1,
              seqNo: 1,
              startX: 0,
              startY: 0,
              length: 100,
              plasterSelected: true,
            ),
            const RoomEditorLine(
              id: 2,
              seqNo: 2,
              startX: 100,
              startY: 0,
              length: 50,
              plasterSelected: true,
            ),
            const RoomEditorLine(
              id: 3,
              seqNo: 3,
              startX: 100,
              startY: 50,
              length: 100,
              plasterSelected: true,
            ),
            const RoomEditorLine(
              id: 4,
              seqNo: 4,
              startX: 0,
              startY: 50,
              length: 50,
              plasterSelected: true,
            ),
          ],
          openings: const [],
        ),
        constraints: const [],
      );

      expect(
        deriveImplicitLengthConflictLineIndices(
          sourceDocument: source,
          attemptedDocument: source,
          movedVertexIndex: 2,
        ),
        isEmpty,
      );
    },
  );

  test('limits added solver conflicts beyond requested constraints', () {
    const requestedKey = RoomEditorConstraintKey(
      lineId: 9,
      type: RoomEditorConstraintType.parallel,
    );
    final keys = deriveConstraintConflictHighlightKeys(
      requestedConstraintKeys: {requestedKey},
      solverViolations: [
        _violation(1, RoomEditorConstraintType.horizontal, 20),
        _violation(2, RoomEditorConstraintType.vertical, 10),
        _violation(3, RoomEditorConstraintType.lineLength, 5),
      ],
      limit: 2,
    );

    expect(keys.length, 3);
    expect(keys, contains(requestedKey));
    expect(
      keys,
      contains(
        const RoomEditorConstraintKey(
          lineId: 1,
          type: RoomEditorConstraintType.horizontal,
        ),
      ),
    );
    expect(
      keys,
      contains(
        const RoomEditorConstraintKey(
          lineId: 2,
          type: RoomEditorConstraintType.vertical,
        ),
      ),
    );
    expect(
      keys,
      isNot(
        contains(
          const RoomEditorConstraintKey(
            lineId: 3,
            type: RoomEditorConstraintType.lineLength,
          ),
        ),
      ),
    );
  });
}

RoomEditorConstraintViolation _violation(
  int lineId,
  RoomEditorConstraintType type,
  double error,
) => RoomEditorConstraintViolation(
  constraint: RoomEditorConstraint(
    lineId: lineId,
    type: type,
    targetValue: type == RoomEditorConstraintType.parallel ? 99 : null,
  ),
  lineIndex: lineId - 1,
  error: error,
);
