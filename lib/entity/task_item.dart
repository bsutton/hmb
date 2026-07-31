/*
 * Copyright © OnePub IP Pty Ltd.
 * S. Brett Sutton. All Rights Reserved.
 *
 * Note: This software is licensed under the GNU General Public License,
 *       with the following exceptions:
 *   • Permitted for internal use within your own business or organization only.
 *   • Any external distribution, resale, or incorporation into products
 *     for third parties is strictly prohibited.
 *
 * See the full license on GitHub:
 * https://github.com/bsutton/hmb/blob/main/LICENSE
 */

/// lib/entity/task_item.dart
library;

import 'package:money2/money2.dart';

import '../util/dart/fixed_ex.dart';
import '../util/dart/measurement_type.dart';
import '../util/dart/money_ex.dart';
import '../util/dart/units.dart';
import 'entity.dart';
import 'helpers/charge_mode.dart';
import 'helpers/labour_calculator.dart';
import 'helpers/material_calculator.dart';
import 'job.dart';
import 'material_price.dart';
import 'task_item_type.dart';

enum LabourEntryMode {
  hours('Hours'),
  dollars('Dollars');

  const LabourEntryMode(this._display);
  final String _display;

  static String getDisplay(LabourEntryMode mode) => mode._display;

  static LabourEntryMode fromString(String value) {
    switch (value) {
      case 'Hours':
        {
          return LabourEntryMode.hours;
        }
      case 'Dollars':
        {
          return LabourEntryMode.dollars;
        }
      default:
        {
          throw ArgumentError('Unknown LabourEntryMode: $value');
        }
    }
  }

  String toSqlString() => _display;
}

/// Represents a single item within a task.
///
/// The item may represent labour, materials, consumables or tools.
/// Calculators:
/// - [MaterialCalculator] for materials/consumables/tools
/// - [LabourCalculator] for labour
///
/// Margins are applied at the **line level** — meaning they
/// are calculated on the total cost of the line, not on
/// individual unit prices. This ensures consistent rounding
/// and aligns with accounting best practices.
class TaskItem extends Entity<TaskItem> {
  // ---- Core fields ----------------------------------------------------------

  final int taskId;
  TaskItemType itemType;
  String description;
  String purpose;

  // ---- Estimates ------------------------------------------------------------

  final Fixed? estimatedLabourHours;
  final Money? estimatedLabourCost;
  final MaterialPrice? estimatedPrice;

  // ---- Actuals --------------------------------------------------------------

  MaterialPrice? actualPrice;

  // ---- Pricing and margin ---------------------------------------------------

  /// Margin applied (as a percentage) to the total **line** cost.
  final Percentage margin;

  /// The total **line** charge for this item including margin.
  /// If chargeMode is userDefined, this is user-entered.
  /// If chargeMode is calculated, this is computed by the
  /// material or labour calculators.
  Money? _totalLineCharge;

  /// Indicates whether the [_totalLineCharge] is user-defined or calculated.
  ChargeMode chargeMode;

  // ---- Status and linkage ---------------------------------------------------

  bool completed;

  /// True if this item has been billed.
  bool billed;

  /// The invoice this item appears on.
  int? invoiceLineId;

  // ---- Measurement and units ------------------------------------------------

  final MeasurementType? measurementType;
  final Fixed dimension1;
  final Fixed dimension2;
  final Fixed dimension3;
  final Units? units;
  final String url;

  // ---- Supplier / labour / returns -----------------------------------------

  int? supplierId;
  final LabourEntryMode labourEntryMode;
  final int? sourceTaskItemId;
  final bool isReturn;

  /// Expose as read-only for helpers when chargeMode == userDefined.
  Money? get userDefinedCharge => _totalLineCharge;

  // ---- Constructors ---------------------------------------------------------

  TaskItem._({
    required super.id,
    required super.createdDate,
    required super.modifiedDate,
    required this.taskId,
    required this.description,
    required this.itemType,
    required this.estimatedPrice,
    required this.estimatedLabourHours,
    required this.estimatedLabourCost,
    required Money? totalLineCharge,
    required this.chargeMode,
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
    required this.actualPrice,
    required this.sourceTaskItemId,
    required this.isReturn,
  }) : _totalLineCharge = totalLineCharge,
       super();

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
    required ChargeMode chargeMode,
    MaterialPrice? estimatedPrice,
    Money? estimatedLabourCost,
    Fixed? estimatedLabourHours,
    Money? totalLineCharge,
    bool completed = false,
    bool billed = false,
    int? invoiceLineId,
    int? supplierId,
    MaterialPrice? actualPrice,
    int? sourceTaskItemId,
    bool isReturn = false,
  }) {
    assert(
      (chargeMode == ChargeMode.userDefined && totalLineCharge != null) ||
          (chargeMode == ChargeMode.calculated && totalLineCharge == null),
      'If chargeMode is userDefined, totalLineCharge must be provided. '
      'If chargeMode is calculated, totalLineCharge must be null.',
    );
    final now = DateTime.now();
    return TaskItem._(
      id: -1,
      createdDate: now,
      modifiedDate: now,
      taskId: taskId,
      description: description,
      itemType: itemType,
      estimatedPrice: estimatedPrice,
      estimatedLabourHours: estimatedLabourHours,
      estimatedLabourCost: estimatedLabourCost,
      margin: margin,
      totalLineCharge: totalLineCharge,
      chargeMode: chargeMode,
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
      actualPrice: actualPrice,
      sourceTaskItemId: sourceTaskItemId,
      isReturn: isReturn,
    );
  }

  TaskItem copyWith({
    int? taskId,
    String? description,
    TaskItemType? itemType,
    MaterialPrice? estimatedPrice,
    bool clearEstimatedPrice = false,
    Fixed? estimatedLabourHours,
    Money? estimatedLabourCost,
    Percentage? margin,
    Money? totalLineCharge,
    ChargeMode? chargeMode,
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
    MaterialPrice? actualPrice,
    bool clearActualPrice = false,
    int? sourceTaskItemId,
    bool? isReturn,
  }) {
    final taskItem = TaskItem._(
      id: id,
      createdDate: createdDate,
      modifiedDate: DateTime.now(),
      taskId: taskId ?? this.taskId,
      description: description ?? this.description,
      purpose: purpose ?? this.purpose,
      itemType: itemType ?? this.itemType,
      estimatedPrice: clearEstimatedPrice
          ? null
          : estimatedPrice ?? this.estimatedPrice,
      estimatedLabourHours: estimatedLabourHours ?? this.estimatedLabourHours,
      estimatedLabourCost: estimatedLabourCost ?? this.estimatedLabourCost,
      totalLineCharge: (chargeMode ?? this.chargeMode) == ChargeMode.calculated
          ? null
          : totalLineCharge ?? _totalLineCharge,
      chargeMode: chargeMode ?? this.chargeMode,
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
      actualPrice: clearActualPrice ? null : actualPrice ?? this.actualPrice,
      sourceTaskItemId: sourceTaskItemId ?? this.sourceTaskItemId,
      isReturn: isReturn ?? this.isReturn,
    );

    assert(
      (taskItem.chargeMode == ChargeMode.userDefined &&
              taskItem._totalLineCharge != null) ||
          (taskItem.chargeMode == ChargeMode.calculated &&
              taskItem._totalLineCharge == null),
      'If chargeMode is userDefined, totalLineCharge must be provided. '
      'If chargeMode is calculated, totalLineCharge must be null.',
    );
    return taskItem;
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) => TaskItem._(
    id: map['id'] as int,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    taskId: map['task_id'] as int,
    description: map['description'] as String,
    itemType: TaskItemType.fromId(map['item_type_id'] as int),
    estimatedPrice: MaterialPrice.fromMapOrNull(map, prefix: 'estimated'),
    estimatedLabourHours: FixedEx.fromIntOrNull(
      map['estimated_labour_hours'] as int?,
    ),
    estimatedLabourCost: MoneyEx.moneyOrNull(
      map['estimated_labour_cost'] as int?,
    ),
    margin: Percentage.fromInt(map['margin'] as int? ?? 0, decimalDigits: 3),
    totalLineCharge: MoneyEx.moneyOrNull(map['total_line_charge'] as int?),
    chargeMode: ChargeMode.fromName(map['charge_mode'] as String?),
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
      (map['labour_entry_mode'] as String?) ?? 'Hours',
    ),
    actualPrice: MaterialPrice.fromMapOrNull(map, prefix: 'actual'),
    sourceTaskItemId: map['source_task_item_id'] as int?,
    isReturn: (map['is_return'] as int? ?? 0) == 1,
  );

  // ---- Calculations via calculators ----------------------------------------

  /// Charge calculation (single source of truth via calculators).
  Money getTotalLineCharge(BillingType billingType, Money hourlyRate) {
    switch (itemType) {
      case TaskItemType.materialsStock:
      case TaskItemType.materialsBuy:
      case TaskItemType.toolsOwn:
      case TaskItemType.toolsBuy:
      case TaskItemType.toolsHire:
      case TaskItemType.consumablesStock:
      case TaskItemType.consumablesBuy:
        {
          final mc = MaterialCalculator(billingType, this);
          return mc.calcMaterialCharges(billingType);
        }
      case TaskItemType.labour:
        {
          return LabourCalculator(billingType, this, hourlyRate).totalCharge;
        }
    }
  }

  Money calcMaterialCharges(BillingType billingType) =>
      MaterialCalculator(billingType, this).calcMaterialCharges(billingType);

  Money calcLabourCharges(BillingType billingType, Money hourlyRate) =>
      LabourCalculator(billingType, this, hourlyRate).totalCharge;

  /// Convenience accessor if you need material cost breakdowns.
  MaterialCalculator calcMaterialCost(BillingType billingType) =>
      MaterialCalculator(billingType, this);

  /// Capture actual purchase costs while keeping material charges calculated
  /// from the current quantity, unit cost, and margin.
  // ignore: use_setters_to_change_properties
  void setActualPrice(MaterialPrice price) {
    actualPrice = price;
  }

  /// Generates a human-readable dimension string.
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

  // ---- Mapping helpers ------------------------------------------------------

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'task_id': taskId,
    'description': description,
    'item_type_id': itemType.id,
    'estimated_price_mode': null,
    'estimated_quantity': null,
    'estimated_unit_cost': null,
    'estimated_items_per_package': null,
    ...?estimatedPrice?.toMap(prefix: 'estimated'),
    'estimated_labour_hours': estimatedLabourHours
        ?.threeDigits()
        .minorUnits
        .toInt(),
    'estimated_labour_cost': estimatedLabourCost
        ?.twoDigits()
        .minorUnits
        .toInt(),
    'margin': margin.threeDigits().minorUnits.toInt(),
    'total_line_charge': _totalLineCharge?.twoDigits().minorUnits.toInt(),
    'charge_mode': chargeMode.name,
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
    'actual_price_mode': null,
    'actual_quantity': null,
    'actual_unit_cost': null,
    'actual_items_per_package': null,
    ...?actualPrice?.toMap(prefix: 'actual'),
    'source_task_item_id': sourceTaskItemId,
    'is_return': isReturn ? 1 : 0,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };

  /// Creates a return item (negative line totals).
  TaskItem forReturn(MaterialPrice returnPrice) {
    final now = DateTime.now();
    return TaskItem._(
      id: -1,
      createdDate: now,
      modifiedDate: now,
      taskId: taskId,
      description: description,
      itemType: itemType,
      estimatedPrice: returnPrice,
      estimatedLabourHours: estimatedLabourHours,
      estimatedLabourCost: estimatedLabourCost,
      margin: margin,
      totalLineCharge: _totalLineCharge,
      chargeMode: chargeMode,
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
      actualPrice: returnPrice,
      sourceTaskItemId: id,
      isReturn: true,
    );
  }
}
