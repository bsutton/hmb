// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: cascade_invocations

import 'dart:math';

import 'package:flutter/material.dart';

import 'benchmark_visual_snapshot.dart';
import 'explorer_units.dart';

class BenchmarkSheetExplorerPane extends StatelessWidget {
  final String solverFamily;
  final BenchmarkVisualScenarioSnapshot scenario;

  const BenchmarkSheetExplorerPane({
    super.key,
    required this.solverFamily,
    required this.scenario,
  });

  @override
  Widget build(BuildContext context) {
    final orderedLayouts = [...scenario.layouts]
      ..sort((left, right) {
        if (left.isCeiling != right.isCeiling) {
          return left.isCeiling ? -1 : 1;
        }
        final roomCompare = left.roomId.compareTo(right.roomId);
        if (roomCompare != 0) {
          return roomCompare;
        }
        return left.label.compareTo(right.label);
      });
    final labels = BenchmarkExplorerSheetLabels.forLayouts(
      scenario.sheets,
      orderedLayouts,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  solverFamily,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${scenario.totalSheetCount} sheets  •  '
                  '${scenario.wastePercent.toStringAsFixed(1)}% waste  •  '
                  '${_formatMeters(scenario.jointTapeLength)} tape',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const BenchmarkProjectSheetLegend(),
                const SizedBox(height: 16),
                for (final layout in orderedLayouts) ...[
                  Text(
                    _surfaceSectionTitle(layout),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final layoutSheets = [
                        for (final sheet in scenario.sheets)
                          if (sheet.usedPieces.any(
                            (piece) => piece.surfaceLabel == layout.label,
                          ))
                            sheet,
                      ];
                      final sheetNumbers = [
                        for (final sheet in layoutSheets)
                          labels.sheetLabel(sheet),
                      ];
                      final placementLabels = _surfacePlacementLabels(
                        layout: layout,
                        sheets: layoutSheets,
                        labels: labels,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BenchmarkSurfaceSheetSection(
                            layout: layout,
                            sheetNumbers: sheetNumbers,
                            placementLabels: placementLabels,
                          ),
                          const SizedBox(height: 12),
                          if (layoutSheets.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(left: 8, bottom: 8),
                              child: Text('No sheets assigned.'),
                            )
                          else
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final sheet in layoutSheets)
                                  BenchmarkProjectSheetCard(
                                    sheet: sheet,
                                    layout: layout,
                                    labels: labels,
                                  ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _surfaceSectionTitle(BenchmarkVisualSurfaceLayout layout) {
  if (layout.isCeiling) {
    return 'Ceiling';
  }
  final wallNumber = layout.lineId;
  return wallNumber == null ? 'Wall' : 'Wall $wallNumber';
}

List<String> _surfacePlacementLabels({
  required BenchmarkVisualSurfaceLayout layout,
  required List<BenchmarkVisualProjectSheet> sheets,
  required BenchmarkExplorerSheetLabels labels,
}) {
  final candidates = <({int width, int height, String label})>[];
  for (final sheet in sheets) {
    final relevantPieces = [
      for (final piece in sheet.usedPieces)
        if (piece.surfaceLabel == layout.label) piece,
    ];
    for (var i = 0; i < relevantPieces.length; i++) {
      final piece = relevantPieces[i];
      final sheetLabel = labels.sheetLabel(sheet);
      final subsheetLabel = labels.subsheetLabelForPiece(sheet, piece);
      final pieceLabel = relevantPieces.length > 1
          ? '$sheetLabel.${i + 1}'
          : subsheetLabel ?? sheetLabel;
      candidates.add((
        width: piece.width,
        height: piece.height,
        label: pieceLabel,
      ));
    }
  }

  return [
    for (final placement in layout.placements)
      _takeMatchingPlacementLabel(candidates, placement) ?? '',
  ];
}

String? _takeMatchingPlacementLabel(
  List<({int width, int height, String label})> candidates,
  BenchmarkVisualSheetPlacement placement,
) {
  final index = candidates.indexWhere(
    (candidate) =>
        candidate.width == placement.width &&
        candidate.height == placement.height,
  );
  if (index == -1) {
    return null;
  }
  return candidates.removeAt(index).label;
}

class BenchmarkProjectSheetLegend extends StatelessWidget {
  const BenchmarkProjectSheetLegend({super.key});

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      _LegendChip(label: 'Fresh sheet piece', color: Color(0xFF4DD8B0)),
      _LegendChip(label: 'Reused offcut piece', color: Color(0xFF8B5CF6)),
      _LegendChip(
        label: 'Reusable offcut not reused',
        color: Color(0xFF4A90E2),
      ),
      _LegendChip(
        label: 'Reusable offcut reused later',
        color: Color(0xFF0EA5A8),
      ),
      _LegendChip(label: 'Scrap', color: Color(0xFFE67E22)),
    ],
  );
}

class BenchmarkExplorerSheetLabels {
  final Map<int, String> _sheetLabelsByNumber;
  final Map<String, String> _subsheetLabelsByPair;

  factory BenchmarkExplorerSheetLabels(
    List<BenchmarkVisualProjectSheet> sheets,
  ) {
    final sheetLabelsByNumber = <int, String>{};
    for (var i = 0; i < sheets.length; i++) {
      sheetLabelsByNumber[sheets[i].sheetNumber] = '${i + 1}';
    }
    return BenchmarkExplorerSheetLabels._fromLabels(
      sheets,
      sheetLabelsByNumber,
    );
  }

  factory BenchmarkExplorerSheetLabels.forLayouts(
    List<BenchmarkVisualProjectSheet> sheets,
    List<BenchmarkVisualSurfaceLayout> layouts,
  ) {
    final sheetLabelsByNumber = <int, String>{};
    var nextLabel = 1;
    for (final layout in layouts) {
      for (final sheet in sheets) {
        if (sheetLabelsByNumber.containsKey(sheet.sheetNumber)) {
          continue;
        }
        final usedOnLayout = sheet.usedPieces.any(
          (piece) => piece.surfaceLabel == layout.label,
        );
        if (usedOnLayout) {
          sheetLabelsByNumber[sheet.sheetNumber] = '${nextLabel++}';
        }
      }
    }
    for (final sheet in sheets) {
      sheetLabelsByNumber.putIfAbsent(
        sheet.sheetNumber,
        () => '${nextLabel++}',
      );
    }
    return BenchmarkExplorerSheetLabels._fromLabels(
      sheets,
      sheetLabelsByNumber,
    );
  }

  factory BenchmarkExplorerSheetLabels._fromLabels(
    List<BenchmarkVisualProjectSheet> sheets,
    Map<int, String> sheetLabelsByNumber,
  ) {
    final nextBranchIndexBySource = <int, int>{};
    final subsheetLabelsByPair = <String, String>{};
    for (final sheet in sheets) {
      final sourceSheets = <int>{
        for (final piece in sheet.usedPieces)
          if (piece.reusedOffcut && piece.sourceSheetNumber != null)
            piece.sourceSheetNumber!,
      }.toList()..sort();
      for (final sourceSheet in sourceSheets) {
        final pairKey = '$sourceSheet:${sheet.sheetNumber}';
        final branchIndex = nextBranchIndexBySource.update(
          sourceSheet,
          (current) => current + 1,
          ifAbsent: () => 1,
        );
        final sourceLabel = sheetLabelsByNumber[sourceSheet] ?? '$sourceSheet';
        subsheetLabelsByPair[pairKey] = '$sourceLabel.$branchIndex';
      }
    }

    return BenchmarkExplorerSheetLabels._(
      sheetLabelsByNumber,
      subsheetLabelsByPair,
    );
  }

  const BenchmarkExplorerSheetLabels._(
    this._sheetLabelsByNumber,
    this._subsheetLabelsByPair,
  );

  String sheetLabel(BenchmarkVisualProjectSheet sheet) =>
      _sheetLabelsByNumber[sheet.sheetNumber] ?? '${sheet.sheetNumber}';

  String? subsheetLabelForPiece(
    BenchmarkVisualProjectSheet sheet,
    BenchmarkVisualProjectSheetPiece piece,
  ) {
    if (!piece.reusedOffcut || piece.sourceSheetNumber == null) {
      return null;
    }
    final pairKey = '${piece.sourceSheetNumber}:${sheet.sheetNumber}';
    return _subsheetLabelsByPair[pairKey];
  }
}

class BenchmarkSurfaceSheetSection extends StatelessWidget {
  final BenchmarkVisualSurfaceLayout layout;
  final List<String> sheetNumbers;
  final List<String> placementLabels;

  const BenchmarkSurfaceSheetSection({
    super.key,
    required this.layout,
    required this.sheetNumbers,
    required this.placementLabels,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BenchmarkSurfaceLayoutDiagram(
            layout: layout,
            width: 168,
            height: 108,
            sheetNumbers: placementLabels,
            showDimensionsOverlay: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  layout.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${layout.materialName}  '
                  '${layout.sheetsAcross} across x ${layout.sheetsDown} high',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(layout.direction.layoutLabel),
                const SizedBox(height: 6),
                Text(
                  sheetNumbers.isEmpty
                      ? 'Sheets: none'
                      : 'Sheets: ${sheetNumbers.join(', ')}',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class BenchmarkSurfaceLayoutDiagram extends StatelessWidget {
  final BenchmarkVisualSurfaceLayout layout;
  final List<String> sheetNumbers;
  final bool showDimensionsOverlay;
  final bool showSheetMeasurements;
  final double width;
  final double height;

  const BenchmarkSurfaceLayoutDiagram({
    super.key,
    required this.layout,
    required this.sheetNumbers,
    required this.showDimensionsOverlay,
    this.showSheetMeasurements = false,
    this.width = 132,
    this.height = 84,
  });

  @override
  Widget build(BuildContext context) {
    final widthLabel = formatExplorerDisplayLength(
      layout.width,
      layout.unitSystem,
    );
    final heightLabel = formatExplorerDisplayLength(
      layout.height,
      layout.unitSystem,
    );
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _SurfaceLayoutDiagramPainter(
          layout: layout,
          showSheetMeasurements: showSheetMeasurements,
          sheetNumbers: sheetNumbers,
        ),
        child: showDimensionsOverlay
            ? Center(
                child: Text(
                  'w: $widthLabel\nh: $heightLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10),
                ),
              )
            : null,
      ),
    );
  }
}

class _SurfaceLayoutDiagramPainter extends CustomPainter {
  final BenchmarkVisualSurfaceLayout layout;
  final bool showSheetMeasurements;
  final List<String> sheetNumbers;

  const _SurfaceLayoutDiagramPainter({
    required this.layout,
    required this.showSheetMeasurements,
    required this.sheetNumbers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = const Color(0xFF2D8CFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()
      ..color = const Color(0x221DC8FF)
      ..style = PaintingStyle.fill;
    final sheet = Paint()
      ..color = const Color(0x4439FFB5)
      ..style = PaintingStyle.fill;
    final sheetBorder = Paint()
      ..color = const Color(0xFF39FFB5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final scale = min(size.width / layout.width, size.height / layout.height);
    final scaledWidth = layout.width * scale;
    final scaledHeight = layout.height * scale;
    final offset = Offset(
      (size.width - scaledWidth) / 2,
      (size.height - scaledHeight) / 2,
    );
    final rect = offset & Size(scaledWidth, scaledHeight);
    canvas.drawRect(rect, fill);
    for (var i = 0; i < layout.placements.length; i++) {
      final placement = layout.placements[i];
      final sheetRect = Rect.fromLTWH(
        offset.dx + placement.x * scale,
        offset.dy + placement.y * scale,
        placement.width * scale,
        placement.height * scale,
      );
      canvas.drawRect(sheetRect, sheet);
      canvas.drawRect(sheetRect, sheetBorder);
      if (i < sheetNumbers.length && sheetNumbers[i].isNotEmpty) {
        _paintSheetNumberBadge(canvas, sheetRect, sheetNumbers[i]);
      }
      if (showSheetMeasurements) {
        final pieceWidth = formatExplorerDisplayLength(
          placement.width,
          layout.unitSystem,
        );
        final pieceHeight = formatExplorerDisplayLength(
          placement.height,
          layout.unitSystem,
        );
        _paintSheetDimensions(canvas, sheetRect, '$pieceWidth\n$pieceHeight');
      }
    }
    canvas.drawRect(rect, border);
  }

  void _paintSheetNumberBadge(Canvas canvas, Rect rect, String text) {
    if (rect.width < 10 || rect.height < 8) {
      return;
    }
    final fontSize = rect.height < 24 ? 9.0 : 10.5;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: max(1, rect.width - 4));
    final badgeWidth = min(rect.width - 2, textPainter.width + 9);
    final badgeHeight = min(rect.height - 2, textPainter.height + 6);
    final badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left + 1, rect.top + 1, badgeWidth, badgeHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(badge, Paint()..color = const Color(0xDD111827));
    textPainter.paint(
      canvas,
      Offset(
        badge.left + (badge.width - textPainter.width) / 2,
        badge.top + (badge.height - textPainter.height) / 2,
      ),
    );
  }

  void _paintSheetDimensions(Canvas canvas, Rect rect, String text) {
    if (rect.width < 54 || rect.height < 26) {
      return;
    }
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: rect.width - 8);
    final background = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: rect.center,
        width: textPainter.width + 8,
        height: textPainter.height + 6,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(background, Paint()..color = const Color(0xBB111827));
    textPainter.paint(
      canvas,
      Offset(
        rect.center.dx - textPainter.width / 2,
        rect.center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _SurfaceLayoutDiagramPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.showSheetMeasurements != showSheetMeasurements ||
      oldDelegate.sheetNumbers != sheetNumbers;
}

class BenchmarkProjectSheetCard extends StatelessWidget {
  final BenchmarkVisualProjectSheet sheet;
  final BenchmarkVisualSurfaceLayout layout;
  final BenchmarkExplorerSheetLabels labels;

  const BenchmarkProjectSheetCard({
    super.key,
    required this.sheet,
    required this.layout,
    required this.labels,
  });

  String _formatLength(int value) =>
      formatExplorerDisplayLength(value, sheet.unitSystem);

  String _formatArea(int area) =>
      formatExplorerDisplayArea(area, sheet.unitSystem);

  String _formatPiece(BenchmarkVisualProjectSheetPiece piece) {
    final sourceLabel = labels.subsheetLabelForPiece(sheet, piece);
    final sourceSuffix = sourceLabel == null ? '' : ' from $sourceLabel';
    return 'width ${_formatLength(piece.width)} x '
        'length ${_formatLength(piece.height)}'
        '${piece.reusedOffcut ? ' reused offcut' : ' fresh'}'
        '$sourceSuffix';
  }

  bool get _rotateForLayout {
    final stockLandscape = sheet.sheetWidth >= sheet.sheetHeight;
    final targetLandscape = switch (layout.direction) {
      ExplorerSheetDirection.horizontal => true,
      ExplorerSheetDirection.vertical => false,
      ExplorerSheetDirection.auto => stockLandscape,
    };
    return targetLandscape != stockLandscape;
  }

  @override
  Widget build(BuildContext context) {
    final rotateForLayout = _rotateForLayout;
    final displayWidth = rotateForLayout ? sheet.sheetHeight : sheet.sheetWidth;
    final displayHeight = rotateForLayout
        ? sheet.sheetWidth
        : sheet.sheetHeight;
    final reusableOffcuts = [
      for (final offcut in sheet.offcuts)
        if (offcut.reusable) offcut,
    ];
    final reusableArea = reusableOffcuts.fold<int>(
      0,
      (sum, offcut) => sum + (offcut.width * offcut.height),
    );
    final scrapArea = sheet.offcuts.fold<int>(
      0,
      (sum, offcut) =>
          sum + (offcut.reusable ? 0 : offcut.width * offcut.height),
    );
    final reusedLaterCount = reusableOffcuts
        .where((offcut) => offcut.reusedLater)
        .length;
    final reusedLaterArea = reusableOffcuts.fold<int>(
      0,
      (sum, offcut) =>
          sum + (offcut.reusedLater ? offcut.width * offcut.height : 0),
    );
    final neverReusedCount = reusableOffcuts.length - reusedLaterCount;
    final neverReusedArea = reusableArea - reusedLaterArea;
    final relevantPieces = [
      for (final piece in sheet.usedPieces)
        if (piece.surfaceLabel == layout.label) piece,
    ];
    final reusedCount = relevantPieces
        .where((piece) => piece.reusedOffcut)
        .length;
    final freshCount = relevantPieces.length - reusedCount;
    final pieceDetails = [
      for (final piece in relevantPieces) _formatPiece(piece),
    ];

    return Container(
      width: 280,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sheet ${labels.sheetLabel(sheet)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            'Width ${_formatLength(displayWidth)} x '
            'Length ${_formatLength(displayHeight)}',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 8),
          BenchmarkProjectSheetDiagram(
            sheet: sheet,
            layout: layout,
            rotateForLayout: rotateForLayout,
            formatLength: _formatLength,
            labels: labels,
          ),
          const SizedBox(height: 8),
          Text('Fresh pieces: $freshCount'),
          Text('Reused-offcut pieces: $reusedCount'),
          Text('Reusable offcuts: ${_formatArea(reusableArea)}'),
          Text(
            'Reused later: '
            '$reusedLaterCount (${_formatArea(reusedLaterArea)})',
          ),
          Text(
            'Not reused: '
            '$neverReusedCount (${_formatArea(neverReusedArea)})',
          ),
          Text('Scrap: ${_formatArea(scrapArea)}'),
          if (pieceDetails.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (var i = 0; i < pieceDetails.length; i++)
              Text(
                'Piece ${i + 1}: ${pieceDetails[i]}',
                style: const TextStyle(fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }
}

class BenchmarkProjectSheetDiagram extends StatelessWidget {
  final BenchmarkVisualProjectSheet sheet;
  final BenchmarkVisualSurfaceLayout layout;
  final bool rotateForLayout;
  final String Function(int value) formatLength;
  final BenchmarkExplorerSheetLabels labels;

  const BenchmarkProjectSheetDiagram({
    super.key,
    required this.sheet,
    required this.layout,
    required this.rotateForLayout,
    required this.formatLength,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    height: 160,
    child: CustomPaint(
      painter: _ProjectSheetExplorerPainter(
        sheet: sheet,
        rotateForLayout: rotateForLayout,
        currentLayoutLabel: layout.label,
        formatLength: formatLength,
        labels: labels,
      ),
    ),
  );
}

class _ProjectSheetDiagramMetrics {
  final BenchmarkVisualProjectSheet sheet;
  final bool rotateForLayout;
  final double scale;
  final Offset offset;

  const _ProjectSheetDiagramMetrics({
    required this.sheet,
    required this.rotateForLayout,
    required this.scale,
    required this.offset,
  });

  factory _ProjectSheetDiagramMetrics.fromSize({
    required BenchmarkVisualProjectSheet sheet,
    required bool rotateForLayout,
    required Size size,
  }) {
    final displaySheetWidth = rotateForLayout
        ? sheet.sheetHeight
        : sheet.sheetWidth;
    final displaySheetHeight = rotateForLayout
        ? sheet.sheetWidth
        : sheet.sheetHeight;
    final scale = min(
      size.width / displaySheetWidth,
      size.height / displaySheetHeight,
    );
    final scaledWidth = displaySheetWidth * scale;
    final scaledHeight = displaySheetHeight * scale;
    final offset = Offset(
      (size.width - scaledWidth) / 2,
      (size.height - scaledHeight) / 2,
    );
    return _ProjectSheetDiagramMetrics(
      sheet: sheet,
      rotateForLayout: rotateForLayout,
      scale: scale,
      offset: offset,
    );
  }

  Rect get bounds =>
      offset &
      Size(
        (rotateForLayout ? sheet.sheetHeight : sheet.sheetWidth) * scale,
        (rotateForLayout ? sheet.sheetWidth : sheet.sheetHeight) * scale,
      );

  Rect sheetRectToCanvas(int x, int y, int width, int height) {
    if (!rotateForLayout) {
      return Rect.fromLTWH(
        offset.dx + x * scale,
        offset.dy + y * scale,
        width * scale,
        height * scale,
      );
    }

    return Rect.fromLTWH(
      offset.dx + (sheet.sheetHeight - y - height) * scale,
      offset.dy + x * scale,
      height * scale,
      width * scale,
    );
  }
}

class _ProjectSheetExplorerPainter extends CustomPainter {
  final BenchmarkVisualProjectSheet sheet;
  final bool rotateForLayout;
  final String currentLayoutLabel;
  final String Function(int value) formatLength;
  final BenchmarkExplorerSheetLabels labels;

  const _ProjectSheetExplorerPainter({
    required this.sheet,
    required this.rotateForLayout,
    required this.currentLayoutLabel,
    required this.formatLength,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final background = Paint()
      ..color = Colors.white.withAlpha(10)
      ..style = PaintingStyle.fill;
    final freshPaint = Paint()..color = const Color(0xFF4DD8B0);
    final reusedPaint = Paint()..color = const Color(0xFF8B5CF6);
    final unusedOffcutPaint = Paint()..color = const Color(0xFF4A90E2);
    final reusedLaterOffcutPaint = Paint()..color = const Color(0xFF0EA5A8);
    final scrapPaint = Paint()..color = const Color(0xFFE67E22);
    final cutLinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final metrics = _ProjectSheetDiagramMetrics.fromSize(
      sheet: sheet,
      rotateForLayout: rotateForLayout,
      size: size,
    );
    final rect = metrics.bounds;
    canvas.drawRect(rect, background);

    for (final piece in sheet.usedPieces) {
      final pieceRect = metrics.sheetRectToCanvas(
        piece.x,
        piece.y,
        piece.width,
        piece.height,
      );
      canvas.drawRect(
        pieceRect,
        _isSameSurfaceReuse(piece) ? freshPaint : reusedPaint,
      );
      canvas.drawRect(pieceRect, cutLinePaint);
      final pieceLabel = _pieceLabel(piece);
      if (pieceLabel != null) {
        _paintPieceBadge(canvas, pieceRect, pieceLabel);
      }
      if (piece.surfaceLabel == currentLayoutLabel) {
        _paintLabel(
          canvas,
          pieceRect,
          '${formatLength(piece.width)}\n${formatLength(piece.height)}',
        );
      }
    }

    for (final offcut in sheet.offcuts) {
      final offcutRect = metrics.sheetRectToCanvas(
        offcut.x,
        offcut.y,
        offcut.width,
        offcut.height,
      );
      canvas.drawRect(
        offcutRect,
        offcut.reusable
            ? (offcut.reusedLater ? reusedLaterOffcutPaint : unusedOffcutPaint)
            : scrapPaint,
      );
      canvas.drawRect(offcutRect, cutLinePaint);
    }

    canvas.drawRect(rect, border);
  }

  String? _pieceLabel(BenchmarkVisualProjectSheetPiece piece) {
    final relevantPieces = [
      for (final candidate in sheet.usedPieces)
        if (candidate.surfaceLabel == piece.surfaceLabel) candidate,
    ];
    if (relevantPieces.length <= 1) {
      return null;
    }
    final index = relevantPieces.indexOf(piece);
    if (index == -1) {
      return null;
    }
    if (relevantPieces.length > 1) {
      return '${labels.sheetLabel(sheet)}.${index + 1}';
    }
    return labels.subsheetLabelForPiece(sheet, piece);
  }

  bool _isSameSurfaceReuse(BenchmarkVisualProjectSheetPiece piece) {
    if (!piece.reusedOffcut) {
      return true;
    }
    return piece.sourceSheetNumber == sheet.sheetNumber &&
        sheet.usedPieces.any(
          (candidate) =>
              !identical(candidate, piece) &&
              candidate.surfaceLabel == piece.surfaceLabel,
        );
  }

  void _paintPieceBadge(Canvas canvas, Rect rect, String text) {
    if (rect.width < 26 || rect.height < 18) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width - 8);
    final badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + 4,
        rect.top + 4,
        painter.width + 8,
        painter.height + 6,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(badge, Paint()..color = const Color(0xDD111827));
    painter.paint(
      canvas,
      Offset(
        badge.left + (badge.width - painter.width) / 2,
        badge.top + (badge.height - painter.height) / 2,
      ),
    );
  }

  void _paintLabel(Canvas canvas, Rect rect, String text) {
    if (rect.width < 48 || rect.height < 24) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: rect.width - 8);
    final bg = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: rect.center,
        width: min(rect.width - 4, painter.width + 8),
        height: painter.height + 6,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(bg, Paint()..color = const Color(0xBB111827));
    painter.paint(
      canvas,
      Offset(
        bg.left + (bg.width - painter.width) / 2,
        bg.top + (bg.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ProjectSheetExplorerPainter oldDelegate) =>
      oldDelegate.sheet != sheet ||
      oldDelegate.rotateForLayout != rotateForLayout ||
      oldDelegate.currentLayoutLabel != currentLayoutLabel ||
      oldDelegate.labels != labels;
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white24),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    ),
  );
}

String _formatMeters(int value) => '${(value.abs() + 9999) ~/ 10000} m';
