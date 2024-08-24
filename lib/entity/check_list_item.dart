import 'package:money2/money2.dart';

import '../util/measurement_type.dart';
import '../util/money_ex.dart';
import '../util/units.dart';
import 'entity.dart';

class CheckListItem extends Entity<CheckListItem> {
  CheckListItem({
    required super.id,
    required this.checkListId,
    required this.description,
    required this.itemTypeId,
    required this.unitCost,
    required this.effortInHours,
    required this.quantity,
    required this.completed,
    required this.billed,
    required super.createdDate,
    required super.modifiedDate,
    required this.measurementType,
    required this.dimension1,
    required this.dimension2,
    required this.dimension3,
    required this.units,
    required this.url,
    this.invoiceLineId,
    this.supplierId, // New field for Supplier
  }) : super();

  CheckListItem.forInsert({
    required this.checkListId,
    required this.description,
    required this.itemTypeId,
    required this.unitCost,
    required this.effortInHours,
    required this.quantity,
    required this.measurementType,
    required this.dimension1,
    required this.dimension2,
    required this.dimension3,
    required this.units,
    required this.url,
    this.completed = false,
    this.billed = false,
    this.invoiceLineId,
    this.supplierId, // New field for Supplier
  }) : super.forInsert();

  CheckListItem.forUpdate({
    required super.entity,
    required this.checkListId,
    required this.description,
    required this.itemTypeId,
    required this.unitCost,
    required this.effortInHours,
    required this.quantity,
    required this.completed,
    required this.billed,
    required this.measurementType,
    required this.dimension1,
    required this.dimension2,
    required this.dimension3,
    required this.units,
    required this.url,
    this.invoiceLineId,
    this.supplierId,
  }) : super.forUpdate();

  factory CheckListItem.fromMap(Map<String, dynamic> map) => CheckListItem(
        id: map['id'] as int,
        checkListId: map['check_list_id'] as int,
        description: map['description'] as String,
        itemTypeId: map['item_type_id'] as int,
        unitCost: MoneyEx.fromInt(map['unit_cost'] as int?),
        effortInHours: Fixed.fromInt(map['effort_in_hours'] as int? ?? 0),
        quantity: Fixed.fromInt(map['quantity'] as int? ?? 1),
        completed: map['completed'] == 1,
        billed: map['billed'] == 1,
        invoiceLineId: map['invoice_line_id'] as int?,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
        measurementType:
            MeasurementType.fromName(map['measurement_type'] as String) ??
                MeasurementType.defaultMeasurementType,
        dimension1: Fixed.fromInt(map['dimension1'] as int? ?? 0, scale: 3),
        dimension2: Fixed.fromInt(map['dimension2'] as int? ?? 0, scale: 3),
        dimension3: Fixed.fromInt(map['dimension3'] as int? ?? 0, scale: 3),
        units: Units.fromName(map['units'] as String) ?? Units.defaultUnits,
        url: map['url'] as String? ?? '',
        supplierId: map['supplier_id'] as int?,
      );

  int checkListId;
  String description;
  int itemTypeId;
  Money unitCost;
  Fixed effortInHours;
  Fixed quantity;
  bool completed;
  bool billed;
  int? invoiceLineId;
  MeasurementType measurementType;
  Fixed dimension1;
  Fixed dimension2;
  Fixed dimension3;
  Units units;
  String url;
  int? supplierId;

  bool get hasCost => unitCost.multiplyByFixed(quantity) > MoneyEx.zero;

  String get dimensions {
    if (!hasDimensions) {
      return '';
    }

    return units.format([dimension1, dimension2, dimension3]);
  }

  bool get hasDimensions => itemTypeId == 1 || itemTypeId == 2;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'check_list_id': checkListId,
        'description': description,
        'item_type_id': itemTypeId,
        'unit_cost': unitCost.copyWith(decimalDigits: 2).minorUnits.toInt(),
        'effort_in_hours':
            Fixed.copyWith(effortInHours, scale: 2).minorUnits.toInt(),
        'quantity': Fixed.copyWith(quantity, scale: 2).minorUnits.toInt(),
        'completed': completed ? 1 : 0,
        'billed': billed ? 1 : 0,
        'invoice_line_id': invoiceLineId,
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
        'measurement_type': measurementType.name,
        'dimension1': Fixed.copyWith(dimension1, scale: 3).minorUnits.toInt(),
        'dimension2': Fixed.copyWith(dimension2, scale: 3).minorUnits.toInt(),
        'dimension3': Fixed.copyWith(dimension3, scale: 3).minorUnits.toInt(),
        'units': units.name,
        'url': url,
        'supplier_id': supplierId, // New field for Supplier
      };

  CheckListItem copyWith({
    int? id,
    int? checkListId,
    String? description,
    int? itemTypeId,
    Money? unitCost,
    Fixed? effortInHours,
    Fixed? quantity,
    bool? completed,
    bool? billed,
    int? invoiceLineId,
    DateTime? createdDate,
    DateTime? modifiedDate,
    MeasurementType? dimensionType,
    Fixed? dimension1,
    Fixed? dimension2,
    Fixed? dimension3,
    Units? units,
    String? url,
  }) =>
      CheckListItem(
        id: id ?? this.id,
        checkListId: checkListId ?? this.checkListId,
        description: description ?? this.description,
        itemTypeId: itemTypeId ?? this.itemTypeId,
        unitCost: unitCost ?? this.unitCost,
        effortInHours: effortInHours ?? this.effortInHours,
        quantity: quantity ?? this.quantity,
        completed: completed ?? this.completed,
        billed: billed ?? this.billed,
        invoiceLineId: invoiceLineId ?? this.invoiceLineId,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate ?? this.modifiedDate,
        measurementType: dimensionType ?? measurementType,
        dimension1: dimension1 ?? this.dimension1,
        dimension2: dimension2 ?? this.dimension2,
        dimension3: dimension3 ?? this.dimension3,
        units: units ?? this.units,
        url: url ?? this.url,
      );

  @override
  String toString() =>
      '''id: $id description: $description qty: $quantity cost: $unitCost completed: $completed billed: $billed dimensions: $dimension1 x $dimension2 x $dimension3 $measurementType ($units) url: $url supplier: $supplierId''';
}
