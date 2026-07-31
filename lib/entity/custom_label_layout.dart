/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import '../util/dart/measurement_type.dart';
import 'entity.dart';

class CustomLabelLayout extends Entity<CustomLabelLayout> {
  final String name;
  final PreferredUnitSystem unitSystem;
  final double pageWidth;
  final double pageHeight;
  final int columns;
  final int rows;
  final double labelWidth;
  final double labelHeight;
  final double marginLeft;
  final double marginTop;
  final double gapX;
  final double gapY;

  CustomLabelLayout._({
    required super.id,
    required this.name,
    required this.unitSystem,
    required this.pageWidth,
    required this.pageHeight,
    required this.columns,
    required this.rows,
    required this.labelWidth,
    required this.labelHeight,
    required this.marginLeft,
    required this.marginTop,
    required this.gapX,
    required this.gapY,
    required super.createdDate,
    required super.modifiedDate,
  });

  CustomLabelLayout.forInsert({
    required this.name,
    required this.unitSystem,
    required this.pageWidth,
    required this.pageHeight,
    required this.columns,
    required this.rows,
    required this.labelWidth,
    required this.labelHeight,
    required this.marginLeft,
    required this.marginTop,
    required this.gapX,
    required this.gapY,
  }) : super.forInsert();

  CustomLabelLayout copyWith({
    String? name,
    PreferredUnitSystem? unitSystem,
    double? pageWidth,
    double? pageHeight,
    int? columns,
    int? rows,
    double? labelWidth,
    double? labelHeight,
    double? marginLeft,
    double? marginTop,
    double? gapX,
    double? gapY,
  }) => CustomLabelLayout._(
    id: id,
    name: name ?? this.name,
    unitSystem: unitSystem ?? this.unitSystem,
    pageWidth: pageWidth ?? this.pageWidth,
    pageHeight: pageHeight ?? this.pageHeight,
    columns: columns ?? this.columns,
    rows: rows ?? this.rows,
    labelWidth: labelWidth ?? this.labelWidth,
    labelHeight: labelHeight ?? this.labelHeight,
    marginLeft: marginLeft ?? this.marginLeft,
    marginTop: marginTop ?? this.marginTop,
    gapX: gapX ?? this.gapX,
    gapY: gapY ?? this.gapY,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory CustomLabelLayout.fromMap(Map<String, dynamic> map) =>
      CustomLabelLayout._(
        id: map['id'] as int,
        name: map['name'] as String,
        unitSystem: PreferredUnitSystem.values.byName(
          map['unit_system'] as String,
        ),
        pageWidth: (map['page_width'] as num).toDouble(),
        pageHeight: (map['page_height'] as num).toDouble(),
        columns: map['columns'] as int,
        rows: map['rows'] as int,
        labelWidth: (map['label_width'] as num).toDouble(),
        labelHeight: (map['label_height'] as num).toDouble(),
        marginLeft: (map['margin_left'] as num).toDouble(),
        marginTop: (map['margin_top'] as num).toDouble(),
        gapX: (map['gap_x'] as num).toDouble(),
        gapY: (map['gap_y'] as num).toDouble(),
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'unit_system': unitSystem.name,
    'page_width': pageWidth,
    'page_height': pageHeight,
    'columns': columns,
    'rows': rows,
    'label_width': labelWidth,
    'label_height': labelHeight,
    'margin_left': marginLeft,
    'margin_top': marginTop,
    'gap_x': gapX,
    'gap_y': gapY,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };
}
