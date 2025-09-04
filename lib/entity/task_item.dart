/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

/// lib/entity/task_item.dart
library;

import 'package:money2/money2.dart';

import '../util/dart/fixed_ex.dart';
import '../util/dart/measurement_type.dart';
import '../util/dart/money_ex.dart';
import '../util/dart/units.dart';
import 'entity.dart';
import 'job.dart';
import 'task_item_type.dart';

/// Specialist enum for labour entry mode
enum LabourEntryMode {
  hours('Hours'),
  dollars('Dollars');

  const LabourEntryMode(this._display);
  final String _display;
  static String getDisplay(LabourEntryMode mode) => mode._display;

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

/// A single task item, including estimates, actuals, billing, URL,
/// purpose, and return linkage
class TaskItem extends Entity<TaskItem> {
  // Primary fields
  final int taskId;
  TaskItemType itemType;
  String description;
  String purpose;

  // Estimates
  final Fixed? estimatedLabourHours;
  final Money? estimatedLabourCost;
  final Money? estimatedMaterialUnitCost;
  final Fixed? estimatedMaterialQuantity;

  // Actuals
  Money? actualMaterialUnitCost;
  Fixed? actualMaterialQuantity;
  Money? actualCost;

  // Margin %
  final Percentage margin;

  // Computed charge
  Money? _charge;
  bool chargeSet;

  // Status
  bool completed;
  bool billed;
  int? invoiceLineId;

  // Dimensions
  final MeasurementType? measurementType;
  final Fixed dimension1;
  final Fixed dimension2;
  final Fixed dimension3;
  final Units? units;
  final String url;

  // Supplier
  int? supplierId;

  // Labour mode
  final LabourEntryMode labourEntryMode;

  // Return linkage
  final int? sourceTaskItemId;
  final bool isReturn;
  TaskItem._({
    required super.id,
    required super.createdDate,
    required super.modifiedDate,
    required this.taskId,
    required this.description,
    required this.itemType,
    required this.estimatedMaterialUnitCost,
    required this.estimatedMaterialQuantity,
    required this.estimatedLabourHours,
    required this.estimatedLabourCost,
    required Money? charge,
    required this.chargeSet,
    required this.margin,
    required this.completed,
    required this.billed,
    required this.measurementType,
    required this.dimension1,
    required this.dimension2,
    required this.dimension3,
    required this.units,
    required this.url,
    required this.purpose,
    required this.labourEntryMode,
    required this.invoiceLineId,
    required this.supplierId,
    required this.actualMaterialUnitCost,
    required this.actualMaterialQuantity,
    required this.actualCost,
    required this.sourceTaskItemId,
    required this.isReturn,
  }) : _charge = charge,
       super();

  /// Constructor for new items
  factory TaskItem.forInsert({
    required int taskId,
    required String description,
    required TaskItemType itemType,
    required Percentage margin,
    required MeasurementType measurementType,
    required Fixed dimension1,
    required Fixed dimension2,
    required Fixed dimension3,
    required Units units,
    required String url,
    required String purpose,
    required LabourEntryMode labourEntryMode,
    Money? estimatedMaterialUnitCost,
    Fixed? estimatedMaterialQuantity,
    Money? estimatedLabourCost,
    Fixed? estimatedLabourHours,
    Money? charge,
    bool completed = false,
    bool billed = false,
    int? invoiceLineId,
    int? supplierId,
    Money? actualMaterialUnitCost,
    Fixed? actualMaterialQuantity,
    Money? actualCost,
    int? sourceTaskItemId,
    bool isReturn = false,
  }) {
    final now = DateTime.now();
    return TaskItem._(
      id: -1,
      createdDate: now,
      modifiedDate: now,
      taskId: taskId,
      description: description,
      itemType: itemType,
      estimatedMaterialUnitCost: estimatedMaterialUnitCost,
      estimatedMaterialQuantity: estimatedMaterialQuantity,
      estimatedLabourHours: estimatedLabourHours,
      estimatedLabourCost: estimatedLabourCost,
      margin: margin,
      charge: charge,
      chargeSet: charge != null,
      completed: completed,
      billed: billed,
      measurementType: measurementType,
      dimension1: dimension1,
      dimension2: dimension2,
      dimension3: dimension3,
      units: units,
      url: url,
      purpose: purpose,
      labourEntryMode: labourEntryMode,
      invoiceLineId: invoiceLineId,
      supplierId: supplierId,
      actualMaterialUnitCost: actualMaterialUnitCost,
      actualMaterialQuantity: actualMaterialQuantity,
      actualCost: actualCost,
      sourceTaskItemId: sourceTaskItemId,
      isReturn: isReturn,
    );
  }

  /// Copy method
  TaskItem copyWith({
    int? taskId,
    String? description,
    TaskItemType? itemType,
    Money? estimatedMaterialUnitCost,
    Fixed? estimatedMaterialQuantity,
    Fixed? estimatedLabourHours,
    Money? estimatedLabourCost,
    Percentage? margin,
    Money? charge,
    bool? chargeSet,
    bool? completed,
    bool? billed,
    int? invoiceLineId,
    MeasurementType? measurementType,
    Fixed? dimension1,
    Fixed? dimension2,
    Fixed? dimension3,
    Units? units,
    String? url,
    String? purpose,
    int? supplierId,
    LabourEntryMode? labourEntryMode,
    Money? actualMaterialUnitCost,
    Fixed? actualMaterialQuantity,
    Money? actualCost,
    int? sourceTaskItemId,
    bool? isReturn,
  }) => TaskItem._(
    id: id,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
    taskId: taskId ?? this.taskId,
    description: description ?? this.description,
    purpose: purpose ?? this.purpose,
    itemType: itemType ?? this.itemType,
    estimatedMaterialUnitCost:
        estimatedMaterialUnitCost ?? this.estimatedMaterialUnitCost,
    estimatedLabourHours: estimatedLabourHours ?? this.estimatedLabourHours,
    estimatedMaterialQuantity:
        estimatedMaterialQuantity ?? this.estimatedMaterialQuantity,
    estimatedLabourCost: estimatedLabourCost ?? this.estimatedLabourCost,
    charge: charge ?? _charge,
    chargeSet: chargeSet ?? this.chargeSet,
    margin: margin ?? this.margin,
    completed: completed ?? this.completed,
    billed: billed ?? this.billed,
    invoiceLineId: invoiceLineId ?? this.invoiceLineId,
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
    sourceTaskItemId: sourceTaskItemId ?? this.sourceTaskItemId,
    isReturn: isReturn ?? this.isReturn,
  );

  /// Parse from database map
  factory TaskItem.fromMap(Map<String, dynamic> map) => TaskItem._(
    id: map['id'] as int,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    taskId: map['task_id'] as int,
    description: map['description'] as String,
    itemType: TaskItemType.fromId(map['item_type_id'] as int),
    estimatedMaterialUnitCost: MoneyEx.moneyOrNull(
      map['estimated_material_unit_cost'] as int?,
    ),
    estimatedMaterialQuantity: FixedEx.fromIntOrNull(
      map['estimated_material_quantity'] as int?,
    ),
    estimatedLabourHours: FixedEx.fromIntOrNull(
      map['estimated_labour_hours'] as int?,
    ),
    estimatedLabourCost: MoneyEx.moneyOrNull(
      map['estimated_labour_cost'] as int? ?? 0,
    ),
    margin: Percentage.fromInt(map['margin'] as int? ?? 0, decimalDigits: 3),
    charge: MoneyEx.moneyOrNull(map['charge'] as int?),

    /// We shouldn't need to check charge but we had some
    /// db entries in an inconsistent state.
    chargeSet: (map['charge_set'] as int) == 1 && map['charge'] != null,
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
    purpose: map['purpose'] as String? ?? '',
    supplierId: map['supplier_id'] as int?,
    labourEntryMode: LabourEntryMode.fromString(
      map['labour_entry_mode'] as String,
    ),
    actualMaterialUnitCost: MoneyEx.moneyOrNull(
      map['actual_material_unit_cost'] as int?,
    ),
    actualMaterialQuantity: FixedEx.fromIntOrNull(
      map['actual_material_quantity'] as int?,
    ),
    actualCost: MoneyEx.moneyOrNull(map['actual_cost'] as int?),
    sourceTaskItemId: map['source_task_item_id'] as int?,
    isReturn: (map['is_return'] as int? ?? 0) == 1,
  );

  /// Charge calculation...
  Money getCharge(BillingType billingType, Money hourlyRate) {
    if (chargeSet) {
      return _charge!;
    }
    switch (itemType) {
      case TaskItemType.materialsStock:
      case TaskItemType.materialsBuy:
      case TaskItemType.toolsOwn:
      case TaskItemType.toolsBuy:
      case TaskItemType.consumablesStock:
      case TaskItemType.consumablesBuy:
        return calcMaterialCharges(billingType);
      case TaskItemType.labour:
        return calcLabourCharges(hourlyRate);
    }
  }

  Money calcMaterialCost(BillingType billingType) => switch (billingType) {
    BillingType.fixedPrice =>
      (estimatedMaterialUnitCost ?? MoneyEx.zero).multiplyByFixed(
        estimatedMaterialQuantity ?? Fixed.one,
      ),
    BillingType.timeAndMaterial => _timeAndMaterialsCost(),
  };

  /// What we will charge the customer including our margin.
  Money calcMaterialCharges(BillingType billingType) {
    final cost = calcMaterialCost(billingType);
    if (chargeSet) {
      /// the users has directly entered the charge field
      /// so we assume they have include the margin.
      return cost;
    } else {
      return cost.plusPercentage(margin);
    }
  }

  /// Calc cost for a Time And Materials job.
  Money _timeAndMaterialsCost() {
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

  void setCharge({
    required BillingType billingType,
    required Money actualMaterialUnitCost,
    required Fixed actualMaterialQuantity,
  }) {
    this.actualMaterialUnitCost = actualMaterialUnitCost;
    this.actualMaterialQuantity = actualMaterialQuantity;

    _charge = calcMaterialCharges(billingType);
    chargeSet = true; // Update chargeSet when charge is set
  }

  /// The charge to the customer which includes our margin
  Money calcLabourCharges(Money hourlyRate) {
    final cost = calcLabourCost(hourlyRate);
    if (chargeSet) {
      /// the users has directly entered the charge field
      /// so we assume they have include the margin.
      return cost;
    } else {
      return cost.plusPercentage(margin);
    }
  }

  Money calcLabourCost(Money hourlyRate) {
    switch (labourEntryMode) {
      case LabourEntryMode.dollars:
        return (chargeSet ? _charge : estimatedLabourCost) ?? MoneyEx.zero;
      case LabourEntryMode.hours:
        if (estimatedLabourHours != null) {
          return (chargeSet
                  ? _charge
                  : hourlyRate.multiplyByFixed(estimatedLabourHours!)) ??
              MoneyEx.zero;
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

  bool get hasDimensions =>
      (itemType == TaskItemType.materialsBuy ||
          itemType == TaskItemType.materialsStock) &&
      (dimension1.isPositive || dimension2.isPositive || dimension3.isPositive);

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'task_id': taskId,
    'description': description,
    'item_type_id': itemType.id,
    'estimated_material_unit_cost': estimatedMaterialUnitCost
        ?.twoDigits()
        .minorUnits
        .toInt(),
    'estimated_material_quantity': estimatedMaterialQuantity
        ?.threeDigits()
        .minorUnits
        .toInt(),
    'estimated_labour_hours': estimatedLabourHours
        ?.threeDigits()
        .minorUnits
        .toInt(),
    'estimated_labour_cost': estimatedLabourCost
        ?.twoDigits()
        .minorUnits
        .toInt(),
    'margin': margin.threeDigits().minorUnits.toInt(),
    'charge': _charge?.twoDigits().minorUnits.toInt(),
    'charge_set': chargeSet ? 1 : 0,
    'completed': completed ? 1 : 0,
    'billed': billed ? 1 : 0,
    'invoice_line_id': invoiceLineId,
    'measurement_type': measurementType?.name,
    'dimension1': dimension1.threeDigits().minorUnits.toInt(),
    'dimension2': dimension2.threeDigits().minorUnits.toInt(),
    'dimension3': dimension3.threeDigits().minorUnits.toInt(),
    'units': units?.name,
    'url': url,
    'purpose': purpose,
    'supplier_id': supplierId,
    'labour_entry_mode': labourEntryMode.toSqlString(),
    'actual_material_unit_cost': actualMaterialUnitCost
        ?.twoDigits()
        .minorUnits
        .toInt(),
    'actual_material_quantity': actualMaterialQuantity
        ?.threeDigits()
        .minorUnits
        .toInt(),
    'actual_cost': actualCost?.twoDigits().minorUnits.toInt(),
    'source_task_item_id': sourceTaskItemId,
    'is_return': isReturn ? 1 : 0,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };

  /// We are returning an purchased item to the store.
  /// Build a brand-new “return” record linked back to this original.
  TaskItem forReturn(Fixed returnQuantity, Money returnUnitPrice) {
    final now = DateTime.now();
    return TaskItem._(
      id: -1, // new row
      createdDate: now,
      modifiedDate: now,
      taskId: taskId,
      description: description,
      itemType: itemType,
      estimatedMaterialUnitCost: estimatedMaterialUnitCost,
      estimatedMaterialQuantity: estimatedMaterialQuantity,
      estimatedLabourHours: estimatedLabourHours,
      estimatedLabourCost: estimatedLabourCost,
      margin: margin,
      charge: _charge,
      chargeSet: chargeSet,
      completed: true,
      billed: false,
      measurementType: measurementType,
      dimension1: dimension1,
      dimension2: dimension2,
      dimension3: dimension3,
      units: units,
      url: url,
      purpose: purpose,
      labourEntryMode: labourEntryMode,
      invoiceLineId: null,
      supplierId: supplierId,
      // these are the “actuals” for the return:
      actualMaterialUnitCost: returnUnitPrice,
      actualMaterialQuantity: returnQuantity,
      actualCost: returnUnitPrice.multiplyByFixed(returnQuantity),
      // link back to the original task item that we are returning.
      sourceTaskItemId: id,
      isReturn: true,
    );
  }
}
