/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';

import '../../../dao/dao_custom_label_layout.dart';
import '../../../entity/custom_label_layout.dart';
import '../../../util/dart/measurement_type.dart';

@immutable
class LabelLayout {
  final String id;
  final String name;
  final PreferredUnitSystem unitSystem;
  final PdfPageFormat pageFormat;
  final int columns;
  final int rows;
  final double labelWidth;
  final double labelHeight;
  final double marginLeft;
  final double marginTop;
  final double columnPitch;
  final double rowPitch;
  final bool custom;

  const LabelLayout({
    required this.id,
    required this.name,
    required this.unitSystem,
    required this.pageFormat,
    required this.columns,
    required this.rows,
    required this.labelWidth,
    required this.labelHeight,
    required this.marginLeft,
    required this.marginTop,
    required this.columnPitch,
    required this.rowPitch,
    this.custom = false,
  });

  int get labelsPerPage => columns * rows;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LabelLayout && other.id == id;

  @override
  int get hashCode => id.hashCode;

  static List<LabelLayout> forUnitSystem(PreferredUnitSystem unitSystem) =>
      all.where((layout) => layout.unitSystem == unitSystem).toList();

  static Future<List<LabelLayout>> availableForUnitSystem(
    PreferredUnitSystem unitSystem,
  ) async {
    final customLayouts = await DaoCustomLabelLayout().getForUnitSystem(
      unitSystem,
    );
    final layouts = [
      ...forUnitSystem(unitSystem),
      for (final layout in customLayouts) LabelLayout.fromCustom(layout),
    ];
    final byId = <String, LabelLayout>{};
    for (final layout in layouts) {
      byId[layout.id] = layout;
    }
    return byId.values.toList();
  }

  static Future<LabelLayout> byId(
    String id, {
    PreferredUnitSystem fallbackUnitSystem = PreferredUnitSystem.metric,
  }) async {
    final layouts = await availableForUnitSystem(fallbackUnitSystem);
    return layouts.firstWhere(
      (layout) => layout.id == id,
      orElse: () => forUnitSystem(fallbackUnitSystem).first,
    );
  }

  factory LabelLayout.fromCustom(CustomLabelLayout layout) => LabelLayout(
    id: 'custom_${layout.id}',
    name: layout.name,
    unitSystem: layout.unitSystem,
    pageFormat: PdfPageFormat(layout.pageWidth, layout.pageHeight),
    columns: layout.columns,
    rows: layout.rows,
    labelWidth: layout.labelWidth,
    labelHeight: layout.labelHeight,
    marginLeft: layout.marginLeft,
    marginTop: layout.marginTop,
    columnPitch: layout.labelWidth + layout.gapX,
    rowPitch: layout.labelHeight + layout.gapY,
    custom: true,
  );

  static final all = <LabelLayout>[
    const LabelLayout(
      id: 'avery_l7160',
      name: 'Avery L7160 A4 - 21 labels',
      unitSystem: PreferredUnitSystem.metric,
      pageFormat: PdfPageFormat.a4,
      columns: 3,
      rows: 7,
      labelWidth: 63.5 * PdfPageFormat.mm,
      labelHeight: 38.1 * PdfPageFormat.mm,
      marginLeft: 7.25 * PdfPageFormat.mm,
      marginTop: 15.15 * PdfPageFormat.mm,
      columnPitch: 66.7 * PdfPageFormat.mm,
      rowPitch: 38.1 * PdfPageFormat.mm,
    ),
    const LabelLayout(
      id: 'avery_l7162',
      name: 'Avery L7162 A4 - 16 labels',
      unitSystem: PreferredUnitSystem.metric,
      pageFormat: PdfPageFormat.a4,
      columns: 2,
      rows: 8,
      labelWidth: 99.1 * PdfPageFormat.mm,
      labelHeight: 33.9 * PdfPageFormat.mm,
      marginLeft: 4.65 * PdfPageFormat.mm,
      marginTop: 13.5 * PdfPageFormat.mm,
      columnPitch: 101.6 * PdfPageFormat.mm,
      rowPitch: 33.9 * PdfPageFormat.mm,
    ),
    const LabelLayout(
      id: 'avery_l7163',
      name: 'Avery L7163 A4 - 14 labels',
      unitSystem: PreferredUnitSystem.metric,
      pageFormat: PdfPageFormat.a4,
      columns: 2,
      rows: 7,
      labelWidth: 99.1 * PdfPageFormat.mm,
      labelHeight: 38.1 * PdfPageFormat.mm,
      marginLeft: 4.65 * PdfPageFormat.mm,
      marginTop: 15.15 * PdfPageFormat.mm,
      columnPitch: 101.6 * PdfPageFormat.mm,
      rowPitch: 38.1 * PdfPageFormat.mm,
    ),
    const LabelLayout(
      id: 'avery_5160',
      name: 'Avery 5160/8160 Letter - 30 labels',
      unitSystem: PreferredUnitSystem.imperial,
      pageFormat: PdfPageFormat.letter,
      columns: 3,
      rows: 10,
      labelWidth: 2.625 * PdfPageFormat.inch,
      labelHeight: 1.0 * PdfPageFormat.inch,
      marginLeft: 0.1875 * PdfPageFormat.inch,
      marginTop: 0.5 * PdfPageFormat.inch,
      columnPitch: 2.75 * PdfPageFormat.inch,
      rowPitch: 1.0 * PdfPageFormat.inch,
    ),
    const LabelLayout(
      id: 'avery_5161',
      name: 'Avery 5161 Letter - 20 labels',
      unitSystem: PreferredUnitSystem.imperial,
      pageFormat: PdfPageFormat.letter,
      columns: 2,
      rows: 10,
      labelWidth: 4.0 * PdfPageFormat.inch,
      labelHeight: 1.0 * PdfPageFormat.inch,
      marginLeft: 0.15625 * PdfPageFormat.inch,
      marginTop: 0.5 * PdfPageFormat.inch,
      columnPitch: 4.1875 * PdfPageFormat.inch,
      rowPitch: 1.0 * PdfPageFormat.inch,
    ),
    const LabelLayout(
      id: 'avery_5162',
      name: 'Avery 5162 Letter - 14 labels',
      unitSystem: PreferredUnitSystem.imperial,
      pageFormat: PdfPageFormat.letter,
      columns: 2,
      rows: 7,
      labelWidth: 4.0 * PdfPageFormat.inch,
      labelHeight: 1.33 * PdfPageFormat.inch,
      marginLeft: 0.15625 * PdfPageFormat.inch,
      marginTop: 0.83 * PdfPageFormat.inch,
      columnPitch: 4.1875 * PdfPageFormat.inch,
      rowPitch: 1.33 * PdfPageFormat.inch,
    ),
    const LabelLayout(
      id: 'avery_5163',
      name: 'Avery 5163 Letter - 10 labels',
      unitSystem: PreferredUnitSystem.imperial,
      pageFormat: PdfPageFormat.letter,
      columns: 2,
      rows: 5,
      labelWidth: 4.0 * PdfPageFormat.inch,
      labelHeight: 2.0 * PdfPageFormat.inch,
      marginLeft: 0.15625 * PdfPageFormat.inch,
      marginTop: 0.5 * PdfPageFormat.inch,
      columnPitch: 4.1875 * PdfPageFormat.inch,
      rowPitch: 2.0 * PdfPageFormat.inch,
    ),
  ];
}
