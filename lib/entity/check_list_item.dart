import 'package:money2/money2.dart';

import '../util/measurement_type.dart';
import '../util/money_ex.dart';
import '../util/units.dart';
import 'entity.g.dart';

class CheckListItem extends Entity<CheckListItem> {
  CheckListItem({
    required super.id,
    required this.checkListId,
    required this.description,
    required this.itemTypeId,
    required this.estimatedMaterialUnitCost,
    required this.estimatedMaterialQuantity,
    required this.estimatedLabourHours,
    required this.estimatedLabourCost,
    required Money? charge,
    required this.margin,
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
    required this.labourEntryMode,
    this.invoiceLineId,
    this.supplierId,
    this.actualMaterialUnitCost,
    this.actualMaterialQuantity,
    this.actualCost,
  }) : _charge = charge,
       super();

  factory CheckListItem.fromMap(Map<String, dynamic> map) => CheckListItem(
    id: map['id'] as int,
    checkListId: map['check_list_id'] as int,
    description: map['description'] as String,
    itemTypeId: map['item_type_id'] as int,
    estimatedMaterialUnitCost: MoneyEx.fromInt(
      map['estimated_material_unit_cost'] as int?,
    ),
    estimatedMaterialQuantity: Fixed.fromInt(
      map['estimated_material_quantity'] as int? ?? 0,
      decimalDigits: 3,
    ),
    estimatedLabourHours: Fixed.fromInt(
      map['estimated_labour_hours'] as int? ?? 0,
      decimalDigits: 3,
    ),
    estimatedLabourCost: MoneyEx.fromInt(
      map['estimated_labour_cost'] as int? ?? 0,
    ),
    charge: MoneyEx.moneyOrNull(map['charge'] as int?),
    margin: Percentage.fromInt(map['margin'] as int? ?? 0, decimalDigits: 3),
    completed: map['completed'] == 1,
    billed: map['billed'] == 1,
    invoiceLineId: map['invoice_line_id'] as int?,
    measurementType:
        MeasurementType.fromName(
          map['measurement_type'] as String? ??
              MeasurementType.defaultMeasurementType.name,
        ) ??
        MeasurementType.defaultMeasurementType,
    dimension1: Fixed.fromInt(map['dimension1'] as int? ?? 0, decimalDigits: 3),
    dimension2: Fixed.fromInt(map['dimension2'] as int? ?? 0, decimalDigits: 3),
    dimension3: Fixed.fromInt(map['dimension3'] as int? ?? 0, decimalDigits: 3),
    units:
        Units.fromName(map['units'] as String? ?? Units.defaultUnits.name) ??
        Units.defaultUnits,
    url: map['url'] as String? ?? '',
    supplierId: map['supplier_id'] as int?,
    labourEntryMode: LabourEntryMode.fromString(
      map['labour_entry_mode'] as String,
    ),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    actualMaterialUnitCost: MoneyEx.fromInt(
      map['actual_material_unit_cost'] as int? ?? 0,
    ),
    actualMaterialQuantity: Fixed.fromInt(
      map['actual_material_quantity'] as int? ?? 0,
      decimalDigits: 3,
    ),
    actualCost: MoneyEx.fromInt(map['actual_cost'] as int? ?? 0),
  );

  CheckListItem.forInsert({
    required this.checkListId,
    required this.description,
    required this.itemTypeId,
    required this.estimatedMaterialUnitCost,
    required this.estimatedLabourHours,
    required this.estimatedMaterialQuantity,
    required this.estimatedLabourCost,
    required Money? charge,
    required this.margin,
    required this.measurementType,
    required this.dimension1,
    required this.dimension2,
    required this.dimension3,
    required this.units,
    required this.url,
    required this.labourEntryMode,
    this.completed = false,
    this.billed = false,
    this.invoiceLineId,
    this.supplierId,
    this.actualMaterialUnitCost,
    this.actualMaterialQuantity,
    this.actualCost,
  }) : _charge = charge,
       super.forInsert();

  CheckListItem.forUpdate({
    required super.entity,
    required this.checkListId,
    required this.description,
    required this.itemTypeId,
    required this.estimatedMaterialUnitCost,
    required this.estimatedLabourHours,
    required this.estimatedMaterialQuantity,
    required this.estimatedLabourCost,
    required this.margin,
    required Money? charge,
    required this.completed,
    required this.billed,
    required this.measurementType,
    required this.dimension1,
    required this.dimension2,
    required this.dimension3,
    required this.units,
    required this.url,
    required this.labourEntryMode,
    this.invoiceLineId,
    this.supplierId,
    this.actualMaterialUnitCost,
    this.actualMaterialQuantity,
    this.actualCost,
  }) : _charge = charge,
       super.forUpdate();

  LabourEntryMode labourEntryMode;

  int checkListId;
  String description;
  int itemTypeId;

  // Labour
  /// For T&M the 'actual' is taken from time_entry's
  /// The estimated labour hours used when [LabourEntryMode.hours] is used.
  Fixed? estimatedLabourHours;

  /// The estimated labour cost.
  /// Used when [LabourEntryMode.dollars] is used.
  Money? estimatedLabourCost;

  // Materials - estimates used for Quote and Estimate
  /// The estimated cost per unit of material.
  Money? estimatedMaterialUnitCost;

  /// The esitmated quantity of the materials.
  Fixed? estimatedMaterialQuantity;

  // T&M uses the actuals, Fixed uses the estimates for
  // the Invoice.
  // Recorded after the material has been purchased.
  Money? actualMaterialUnitCost;
  Fixed? actualMaterialQuantity;

  // Only used by Fixed for P&L reporting
  Money? actualCost;

  /// The margin to apply to the costs to derive the
  /// charge.
  Percentage margin;

  /// The amount we will charge the customer.
  /// For T&M this is an estimate
  /// for Fixed this is the actual.
  /// If null then the charge is calculated from
  /// the estimation fields. If non-null
  /// then the charge is used and the estimates
  /// are ignored.
  Money? _charge;

  Money getCharge(BillingType billingType, Money hourlyRate) {
    if (_charge != null) {
      return _charge!;
    }

    switch (TaskItemTypeEnum.fromId(itemTypeId)) {
      case TaskItemTypeEnum.materialsBuy:
      case TaskItemTypeEnum.materialsStock:
      case TaskItemTypeEnum.toolsBuy:
      case TaskItemTypeEnum.toolsOwn:
        return calcMaterialCost(billingType).plusPercentage(margin);
      case TaskItemTypeEnum.labour:
        return calcLabourCost(hourlyRate).plusPercentage(margin);
    }
  }

  // ignore: use_setters_to_change_properties
  void setCharge(Money value) {
    _charge = value;
  }

  /// For fixed price we always use the estimated cost.
  /// For T&M we use the estimated cost until we have
  /// the actual cost.
  Money calcMaterialCost(BillingType billingType) {
    if (billingType == BillingType.fixedPrice) {
      return (estimatedMaterialUnitCost ?? MoneyEx.zero).multiplyByFixed(
        estimatedMaterialQuantity ?? Fixed.one,
      );
    } else {
      final cost =
          actualMaterialUnitCost ?? estimatedMaterialUnitCost ?? MoneyEx.zero;
      final quantity =
          actualMaterialQuantity ?? estimatedMaterialQuantity ?? Fixed.one;
      return cost.multiplyByFixed(quantity);
    }
  }

  Money calcLabourCost(Money hourlyRate) {
    switch (labourEntryMode) {
      case LabourEntryMode.dollars:
        return _charge ?? estimatedLabourCost ?? MoneyEx.zero;
      case LabourEntryMode.hours:
        if (estimatedLabourHours != null) {
          return _charge ?? hourlyRate.multiplyByFixed(estimatedLabourHours!);
        }
    }
    return MoneyEx.zero;
  }

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

  bool get hasCost =>
      estimatedMaterialUnitCost != null &&
      estimatedMaterialUnitCost!.multiplyByFixed(
            estimatedMaterialQuantity ?? Fixed.one,
          ) >
          MoneyEx.zero;

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
    'estimated_material_unit_cost': estimatedMaterialUnitCost
        ?.copyWith(decimalDigits: 2)
        .minorUnits
        .toInt(),
    'estimated_material_quantity': estimatedMaterialQuantity
        ?.copyWith(decimalDigits: 3)
        .minorUnits
        .toInt(),
    'estimated_labour_hours': estimatedLabourHours
        ?.copyWith(decimalDigits: 3)
        .minorUnits
        .toInt(),
    'estimated_labour_cost': estimatedLabourCost
        ?.copyWith(decimalDigits: 2)
        .minorUnits
        .toInt(),
    'margin': margin.copyWith(decimalDigits: 3).minorUnits.toInt(),
    'charge': _charge?.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'labour_entry_mode': labourEntryMode.toSqlString(),
    'completed': completed ? 1 : 0,
    'billed': billed ? 1 : 0,
    'invoice_line_id': invoiceLineId,
    'measurement_type': measurementType.name,
    'dimension1': dimension1.copyWith(decimalDigits: 3).minorUnits.toInt(),
    'dimension2': dimension2.copyWith(decimalDigits: 3).minorUnits.toInt(),
    'dimension3': dimension3.copyWith(decimalDigits: 3).minorUnits.toInt(),
    'units': units.name,
    'url': url,
    'supplier_id': supplierId,
    'actual_material_unit_cost': actualMaterialUnitCost
        ?.copyWith(decimalDigits: 2)
        .minorUnits
        .toInt(),
    'actual_material_quantity': actualMaterialQuantity
        ?.copyWith(decimalDigits: 3)
        .minorUnits
        .toInt(),
    'actual_cost': actualCost?.copyWith(decimalDigits: 2).minorUnits.toInt(),
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
  CheckListItem copyWith({
    int? id,
    int? checkListId,
    String? description,
    int? itemTypeId,
    Money? estimatedMaterialCost,
    Fixed? estimatedMaterialQuantity,
    Fixed? estimatedLabour,
    Money? estimatedLabourCost,
    Money? charge,
    Percentage? margin,
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
    LabourEntryMode? labourEntryMode,
    Money? actualMaterialUnitCost,
    Fixed? actualMaterialQuantity,
    Money? actualCost,
  }) => CheckListItem(
    id: id ?? this.id,
    checkListId: checkListId ?? this.checkListId,
    description: description ?? this.description,
    itemTypeId: itemTypeId ?? this.itemTypeId,
    estimatedMaterialUnitCost:
        estimatedMaterialCost ?? estimatedMaterialUnitCost,
    estimatedLabourHours: estimatedLabour ?? estimatedLabourHours,
    estimatedMaterialQuantity:
        estimatedMaterialQuantity ?? this.estimatedMaterialQuantity,
    estimatedLabourCost: estimatedLabourCost ?? this.estimatedLabourCost,
    charge: charge ?? _charge,
    margin: margin ?? this.margin,
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
    labourEntryMode: labourEntryMode ?? this.labourEntryMode,
    url: url ?? this.url,
    actualMaterialUnitCost:
        actualMaterialUnitCost ?? this.actualMaterialUnitCost,
    actualMaterialQuantity:
        actualMaterialQuantity ?? this.actualMaterialQuantity,
    actualCost: actualCost ?? this.actualCost,
  );

  @override
  String toString() =>
      '''id: $id description: $description qty: $estimatedMaterialQuantity cost: $estimatedMaterialUnitCost completed: $completed billed: $billed dimensions: $dimension1 x $dimension2 x $dimension3 $measurementType ($units) url: $url supplier: $supplierId actualMaterialCost: $actualMaterialUnitCost actualMaterialQuantity: $actualMaterialQuantity actualCost: $actualCost''';
}
