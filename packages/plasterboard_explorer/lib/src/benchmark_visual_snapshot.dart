import 'explorer_units.dart';

class BenchmarkVisualSnapshotSet {
  final int schemaVersion;
  final String scoringVersion;
  final String solverFamily;
  final List<BenchmarkVisualScenarioSnapshot> scenarios;

  const BenchmarkVisualSnapshotSet({
    required this.schemaVersion,
    required this.scoringVersion,
    required this.solverFamily,
    required this.scenarios,
  });

  factory BenchmarkVisualSnapshotSet.fromJson(Map<String, dynamic> json) =>
      BenchmarkVisualSnapshotSet(
        schemaVersion: json['schemaVersion'] as int,
        scoringVersion: json['scoringVersion'] as String,
        solverFamily: json['solverFamily'] as String,
        scenarios: [
          for (final scenario
              in json['scenarios'] as List<dynamic>? ?? const <dynamic>[])
            BenchmarkVisualScenarioSnapshot.fromJson(
              scenario as Map<String, dynamic>,
            ),
        ],
      );

  Map<String, BenchmarkVisualScenarioSnapshot> get scenariosById => {
    for (final scenario in scenarios) scenario.scenarioId: scenario,
  };

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'scoringVersion': scoringVersion,
    'solverFamily': solverFamily,
    'scenarios': [for (final scenario in scenarios) scenario.toJson()],
  };
}

class BenchmarkVisualScenarioSnapshot {
  final String scenarioId;
  final String scenarioName;
  final int totalSheetCount;
  final double wastePercent;
  final int jointTapeLength;
  final List<BenchmarkVisualSurfaceLayout> layouts;
  final List<BenchmarkVisualProjectSheet> sheets;

  const BenchmarkVisualScenarioSnapshot({
    required this.scenarioId,
    required this.scenarioName,
    required this.totalSheetCount,
    required this.wastePercent,
    required this.jointTapeLength,
    required this.layouts,
    required this.sheets,
  });

  factory BenchmarkVisualScenarioSnapshot.fromJson(
    Map<String, dynamic> json,
  ) => BenchmarkVisualScenarioSnapshot(
    scenarioId: json['scenarioId'] as String,
    scenarioName: json['scenarioName'] as String,
    totalSheetCount: json['totalSheetCount'] as int,
    wastePercent: (json['wastePercent'] as num).toDouble(),
    jointTapeLength: json['jointTapeLength'] as int,
    layouts: [
      for (final layout
          in json['layouts'] as List<dynamic>? ?? const <dynamic>[])
        BenchmarkVisualSurfaceLayout.fromJson(layout as Map<String, dynamic>),
    ],
    sheets: [
      for (final sheet in json['sheets'] as List<dynamic>? ?? const <dynamic>[])
        BenchmarkVisualProjectSheet.fromJson(sheet as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    'scenarioId': scenarioId,
    'scenarioName': scenarioName,
    'totalSheetCount': totalSheetCount,
    'wastePercent': wastePercent,
    'jointTapeLength': jointTapeLength,
    'layouts': [for (final layout in layouts) layout.toJson()],
    'sheets': [for (final sheet in sheets) sheet.toJson()],
  };
}

class BenchmarkVisualSurfaceLayout {
  final int roomId;
  final int? lineId;
  final bool isCeiling;
  final String label;
  final String materialName;
  final ExplorerUnitSystem unitSystem;
  final ExplorerSheetDirection direction;
  final int width;
  final int height;
  final int sheetCount;
  final int sheetsAcross;
  final int sheetsDown;
  final List<BenchmarkVisualSheetPlacement> placements;

  const BenchmarkVisualSurfaceLayout({
    required this.roomId,
    required this.lineId,
    required this.isCeiling,
    required this.label,
    required this.materialName,
    required this.unitSystem,
    required this.direction,
    required this.width,
    required this.height,
    required this.sheetCount,
    required this.sheetsAcross,
    required this.sheetsDown,
    required this.placements,
  });

  factory BenchmarkVisualSurfaceLayout.fromJson(Map<String, dynamic> json) =>
      BenchmarkVisualSurfaceLayout(
        roomId: json['roomId'] as int,
        lineId: json['lineId'] as int?,
        isCeiling: json['isCeiling'] as bool,
        label: json['label'] as String,
        materialName: json['materialName'] as String,
        unitSystem: ExplorerUnitSystem.values.byName(
          json['unitSystem'] as String,
        ),
        direction: ExplorerSheetDirection.values.byName(
          json['direction'] as String,
        ),
        width: json['width'] as int,
        height: json['height'] as int,
        sheetCount: json['sheetCount'] as int,
        sheetsAcross: json['sheetsAcross'] as int,
        sheetsDown: json['sheetsDown'] as int,
        placements: [
          for (final placement
              in json['placements'] as List<dynamic>? ?? const <dynamic>[])
            BenchmarkVisualSheetPlacement.fromJson(
              placement as Map<String, dynamic>,
            ),
        ],
      );

  Map<String, dynamic> toJson() => {
    'roomId': roomId,
    'lineId': lineId,
    'isCeiling': isCeiling,
    'label': label,
    'materialName': materialName,
    'unitSystem': unitSystem.name,
    'direction': direction.name,
    'width': width,
    'height': height,
    'sheetCount': sheetCount,
    'sheetsAcross': sheetsAcross,
    'sheetsDown': sheetsDown,
    'placements': [for (final placement in placements) placement.toJson()],
  };
}

class BenchmarkVisualSheetPlacement {
  final int x;
  final int y;
  final int width;
  final int height;

  const BenchmarkVisualSheetPlacement({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BenchmarkVisualSheetPlacement.fromJson(Map<String, dynamic> json) =>
      BenchmarkVisualSheetPlacement(
        x: json['x'] as int,
        y: json['y'] as int,
        width: json['width'] as int,
        height: json['height'] as int,
      );

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class BenchmarkVisualProjectSheet {
  final int sheetNumber;
  final String materialName;
  final ExplorerUnitSystem unitSystem;
  final int sheetWidth;
  final int sheetHeight;
  final List<BenchmarkVisualProjectSheetPiece> usedPieces;
  final List<BenchmarkVisualOffcut> offcuts;

  const BenchmarkVisualProjectSheet({
    required this.sheetNumber,
    required this.materialName,
    required this.unitSystem,
    required this.sheetWidth,
    required this.sheetHeight,
    required this.usedPieces,
    required this.offcuts,
  });

  factory BenchmarkVisualProjectSheet.fromJson(Map<String, dynamic> json) =>
      BenchmarkVisualProjectSheet(
        sheetNumber: json['sheetNumber'] as int,
        materialName: json['materialName'] as String,
        unitSystem: ExplorerUnitSystem.values.byName(
          json['unitSystem'] as String,
        ),
        sheetWidth: json['sheetWidth'] as int,
        sheetHeight: json['sheetHeight'] as int,
        usedPieces: [
          for (final piece
              in json['usedPieces'] as List<dynamic>? ?? const <dynamic>[])
            BenchmarkVisualProjectSheetPiece.fromJson(
              piece as Map<String, dynamic>,
            ),
        ],
        offcuts: [
          for (final offcut
              in json['offcuts'] as List<dynamic>? ?? const <dynamic>[])
            BenchmarkVisualOffcut.fromJson(offcut as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => {
    'sheetNumber': sheetNumber,
    'materialName': materialName,
    'unitSystem': unitSystem.name,
    'sheetWidth': sheetWidth,
    'sheetHeight': sheetHeight,
    'usedPieces': [for (final piece in usedPieces) piece.toJson()],
    'offcuts': [for (final offcut in offcuts) offcut.toJson()],
  };
}

class BenchmarkVisualProjectSheetPiece {
  final String surfaceLabel;
  final bool reusedOffcut;
  final int? sourceSheetNumber;
  final int x;
  final int y;
  final int width;
  final int height;

  const BenchmarkVisualProjectSheetPiece({
    required this.surfaceLabel,
    required this.reusedOffcut,
    required this.sourceSheetNumber,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BenchmarkVisualProjectSheetPiece.fromJson(
    Map<String, dynamic> json,
  ) => BenchmarkVisualProjectSheetPiece(
    surfaceLabel: json['surfaceLabel'] as String,
    reusedOffcut: json['reusedOffcut'] as bool,
    sourceSheetNumber: json['sourceSheetNumber'] as int?,
    x: json['x'] as int,
    y: json['y'] as int,
    width: json['width'] as int,
    height: json['height'] as int,
  );

  Map<String, dynamic> toJson() => {
    'surfaceLabel': surfaceLabel,
    'reusedOffcut': reusedOffcut,
    'sourceSheetNumber': sourceSheetNumber,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class BenchmarkVisualOffcut {
  final bool reusable;
  final bool reusedLater;
  final int x;
  final int y;
  final int width;
  final int height;

  const BenchmarkVisualOffcut({
    required this.reusable,
    required this.reusedLater,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BenchmarkVisualOffcut.fromJson(Map<String, dynamic> json) =>
      BenchmarkVisualOffcut(
        reusable: json['reusable'] as bool,
        reusedLater: json['reusedLater'] as bool,
        x: json['x'] as int,
        y: json['y'] as int,
        width: json['width'] as int,
        height: json['height'] as int,
      );

  Map<String, dynamic> toJson() => {
    'reusable': reusable,
    'reusedLater': reusedLater,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}
