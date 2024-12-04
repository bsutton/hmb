import 'package:money2/money2.dart';

import '../util/fixed_ex.dart';
import '../util/measurement_type.dart';
import '../util/money_ex.dart';
import '../util/units.dart';
import 'entity.dart';
import 'job.dart';
import 'task_item_type.dart';

enum LabourEntryMode {
  hours('Hours'),
  dollars('Dollars');

  const LabourEntryMode(this._display);
  final String _display;

  static String getDisplay(LabourEntryMode mode) {
    switch (mode) {
      case LabourEntryMode.hours:
        return LabourEntryMode.hours._display;
      case LabourEntryMode.dollars:
        return LabourEntryMode.dollars._display;
    }
  }

  static LabourEntryMode fromString(String value) {
    switch (value) {
      case 'Hours':
        return LabourEntryMode.hours;
      case 'Dollars':
        return LabourEntryMode.dollars;
      default:
        throw ArgumentError('Unknown LabourEntryMode: $value');
    }
  }

  String toSqlString() => _display;
}

class TaskItem extends Entity<TaskItem> {
  TaskItem({
    required super.id,
    required this.taskId,
    required this.description,
    required this.itemTypeId,
    required this.estimatedMaterialUnitCost,
    required this.estimatedMaterialQuantity,
    required this.estimatedLabourHours,
    required this.estimatedLabourCost,
    required Money? charge,
    required this.chargeSet, // New field
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
  })  : _charge = charge,
        super();

  TaskItem.forInsert({
    required this.taskId,
    required this.description,
    required this.itemTypeId,
    required this.estimatedMaterialUnitCost,
    required this.estimatedLabourHours,
    required this.estimatedMaterialQuantity,
    required this.estimatedLabourCost,
    required this.margin,
    required Money? charge,
    required this.chargeSet, // New field
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
  })  : _charge = charge,
        super.forInsert();

  TaskItem.forUpdate({
    required super.entity,
    required this.taskId,
    required this.description,
    required this.itemTypeId,
    required this.estimatedMaterialUnitCost,
    required this.estimatedLabourHours,
    required this.estimatedMaterialQuantity,
    required this.estimatedLabourCost,
    required this.margin,
    required Money? charge,
    required this.chargeSet, // New field
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
  })  : _charge = charge,
        super.forUpdate();

  factory TaskItem.fromMap(Map<String, dynamic> map) => TaskItem(
        id: map['id'] as int,
        taskId: map['task_id'] as int,
        description: map['description'] as String,
        itemTypeId: map['item_type_id'] as int,
        estimatedMaterialUnitCost:
            MoneyEx.fromInt(map['estimated_material_unit_cost'] as int?),
        estimatedMaterialQuantity: Fixed.fromInt(
            map['estimated_material_quantity'] as int? ?? 0,
            scale: 3),
        estimatedLabourHours:
            Fixed.fromInt(map['estimated_labour_hours'] as int? ?? 0, scale: 3),
        estimatedLabourCost:
            MoneyEx.fromInt(map['estimated_labour_cost'] as int? ?? 0),
        margin:
            Percentage.fromInt(map['margin'] as int? ?? 0, decimalDigits: 3),
        charge: MoneyEx.moneyOrNull(map['charge'] as int?),
        chargeSet: (map['charge_set'] as int) == 1, // New field
        completed: map['completed'] == 1,
        billed: map['billed'] == 1,
        invoiceLineId: map['invoice_line_id'] as int?,
        measurementType: MeasurementType.fromName(
                map['measurement_type'] as String? ??
                    MeasurementType.defaultMeasurementType.name) ??
            MeasurementType.defaultMeasurementType,
        dimension1: Fixed.fromInt(map['dimension1'] as int? ?? 0, scale: 3),
        dimension2: Fixed.fromInt(map['dimension2'] as int? ?? 0, scale: 3),
        dimension3: Fixed.fromInt(map['dimension3'] as int? ?? 0, scale: 3),
        units: Units.fromName(
                map['units'] as String? ?? Units.defaultUnits.name) ??
            Units.defaultUnits,
        url: map['url'] as String? ?? '',
        supplierId: map['supplier_id'] as int?,
        labourEntryMode:
            LabourEntryMode.fromString(map['labour_entry_mode'] as String),
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
        actualMaterialUnitCost:
            MoneyEx.fromInt(map['actual_material_unit_cost'] as int? ?? 0),
        actualMaterialQuantity: Fixed.fromInt(
            map['actual_material_quantity'] as int? ?? 0,
            scale: 3),
        actualCost: MoneyEx.fromInt(map['actual_cost'] as int? ?? 0),
      );

  int taskId;
  String description;
  int itemTypeId;
  Fixed? estimatedLabourHours;
  Money? estimatedLabourCost;
  Money? estimatedMaterialUnitCost;
  Fixed? estimatedMaterialQuantity;
  Money? actualMaterialUnitCost;
  Fixed? actualMaterialQuantity;
  Money? actualCost;
  Percentage margin;
  Money? _charge;
  bool chargeSet; // New field
  bool completed;
  bool billed;
  int? invoiceLineId;
  MeasurementType? measurementType;
  Fixed dimension1;
  Fixed dimension2;
  Fixed dimension3;
  Units? units;
  String url;
  int? supplierId;
  LabourEntryMode labourEntryMode;

  Money getCharge(BillingType billingType, Money hourlyRate) {
    if (chargeSet && _charge != null) {
      return _charge!;
    }
    switch (TaskItemTypeEnum.fromId(itemTypeId)) {
      case TaskItemTypeEnum.materialsBuy:
      case TaskItemTypeEnum.materialsStock:
      case TaskItemTypeEnum.toolsBuy:
      case TaskItemTypeEnum.toolsOwn:
        return calcMaterialCost(billingType)
            .multiplyByFixed(Fixed.one + margin);
      case TaskItemTypeEnum.labour:
        return calcLabourCost(hourlyRate).multiplyByFixed(Fixed.one + margin);
    }
  }

  Money calcMaterialCost(BillingType billingType) => switch (billingType) {
        BillingType.fixedPrice => (estimatedMaterialUnitCost ?? MoneyEx.zero)
            .multiplyByFixed(estimatedMaterialQuantity ?? Fixed.one),
        BillingType.timeAndMaterial => _tAndMCost()
      };

  /// Calc cost for a Time And Materials job.
  Money _tAndMCost() {
    var quantity = Fixed.one;
    var cost = MoneyEx.zero;

    if (completed) {
      cost = actualMaterialUnitCost ?? MoneyEx.zero;
      quantity = actualMaterialQuantity ?? Fixed.one;
    } else {
      cost = estimatedMaterialUnitCost ?? MoneyEx.zero;
      quantity = estimatedMaterialQuantity ?? Fixed.one;
    }
    return cost.multiplyByFixed(quantity);
  }

  void setCharge(Money value) {
    _charge = value;
    chargeSet = true; // Update chargeSet when charge is set
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

  String get dimensions {
    if (!hasDimensions) {
      return '';
    }

    return units?.format([dimension1, dimension2, dimension3]) ?? '';
  }

  bool get hasDimensions => itemTypeId == 1 || itemTypeId == 2;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'task_id': taskId,
        'description': description,
        'item_type_id': itemTypeId,
        'estimated_material_unit_cost':
            estimatedMaterialUnitCost?.twoDigits().minorUnits.toInt(),
        'estimated_material_quantity':
            estimatedMaterialQuantity?.threeDigits().minorUnits.toInt(),
        'estimated_labour_hours':
            estimatedLabourHours?.threeDigits().minorUnits.toInt(),
        'estimated_labour_cost':
            estimatedLabourCost?.twoDigits().minorUnits.toInt(),
        'margin': margin.threeDigits().minorUnits.toInt(),
        'charge': _charge?.twoDigits().minorUnits.toInt(),
        'charge_set': chargeSet ? 1 : 0, // New field
        'completed': completed ? 1 : 0,
        'billed': billed ? 1 : 0,
        'invoice_line_id': invoiceLineId,
        'measurement_type': measurementType?.name,
        'dimension1': dimension1.threeDigits().minorUnits.toInt(),
        'dimension2': dimension2.threeDigits().minorUnits.toInt(),
        'dimension3': dimension3.threeDigits().minorUnits.toInt(),
        'units': units?.name,
        'url': url,
        'supplier_id': supplierId,
        'labour_entry_mode': labourEntryMode.toSqlString(),
        'actual_material_unit_cost':
            actualMaterialUnitCost?.twoDigits().minorUnits.toInt(),
        'actual_material_quantity':
            actualMaterialQuantity?.threeDigits().minorUnits.toInt(),
        'actual_cost': actualCost?.twoDigits().minorUnits.toInt(),
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
      };

  TaskItem copyWith({
    int? id,
    int? taskId,
    String? description,
    int? itemTypeId,
    Money? estimatedMaterialUnitCost,
    Fixed? estimatedMaterialQuantity,
    Fixed? estimatedLabourHours,
    Money? estimatedLabourCost,
    Percentage? margin,
    Money? charge,
    bool? chargeSet, // New field
    bool? completed,
    bool? billed,
    int? invoiceLineId,
    DateTime? createdDate,
    DateTime? modifiedDate,
    MeasurementType? measurementType,
    Fixed? dimension1,
    Fixed? dimension2,
    Fixed? dimension3,
    Units? units,
    String? url,
    int? supplierId,
    LabourEntryMode? labourEntryMode,
    Money? actualMaterialUnitCost,
    Fixed? actualMaterialQuantity,
    Money? actualCost,
  }) =>
      TaskItem(
        id: id ?? this.id,
        taskId: taskId ?? this.taskId,
        description: description ?? this.description,
        itemTypeId: itemTypeId ?? this.itemTypeId,
        estimatedMaterialUnitCost:
            estimatedMaterialUnitCost ?? this.estimatedMaterialUnitCost,
        estimatedLabourHours: estimatedLabourHours ?? this.estimatedLabourHours,
        estimatedMaterialQuantity:
            estimatedMaterialQuantity ?? this.estimatedMaterialQuantity,
        estimatedLabourCost: estimatedLabourCost ?? this.estimatedLabourCost,
        charge: charge ?? _charge,
        chargeSet: chargeSet ?? this.chargeSet, // New field
        margin: margin ?? this.margin,
        completed: completed ?? this.completed,
        billed: billed ?? this.billed,
        invoiceLineId: invoiceLineId ?? this.invoiceLineId,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate ?? this.modifiedDate,
        measurementType: measurementType ?? this.measurementType,
        dimension1: dimension1 ?? this.dimension1,
        dimension2: dimension2 ?? this.dimension2,
        dimension3: dimension3 ?? this.dimension3,
        units: units ?? this.units,
        supplierId: supplierId ?? this.supplierId,
        labourEntryMode: labourEntryMode ?? this.labourEntryMode,
        url: url ?? this.url,
        actualMaterialUnitCost:
            actualMaterialUnitCost ?? this.actualMaterialUnitCost,
        actualMaterialQuantity:
            actualMaterialQuantity ?? this.actualMaterialQuantity,
        actualCost: actualCost ?? this.actualCost,
      );
}
