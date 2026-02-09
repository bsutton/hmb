/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:money2/money2.dart';

import '../util/dart/fixed_ex.dart';
import '../util/dart/measurement_type.dart';
import '../util/dart/money_ex.dart';
import '../util/dart/units.dart';
import 'entity.dart';
import 'helpers/charge_mode.dart';
import 'job.dart';
import 'task.dart';
import 'task_item.dart';
import 'task_item_type.dart';
import 'task_status.dart';

/// A catalog/template estimate for a common task.
/// Think "Trim a wooden door", "Fit new mixer tap", etc.
/// Designed to spawn a Task + one TaskItem starter.
class TaskEstimate extends Entity<TaskEstimate> {
  // ---- Identity / catalog fields
  String name; // e.g. "Trim a wooden door"
  String summary; // client-friendly short blurb
  String description; // internal detail
  String assumption; // e.g. "Door already hung; minor trim only"
  String inclusions; // what is included in price
  String exclusions; // what is not included (risk control)
  String tags; // CSV tags for search e.g. "carpentry,door,trim"
  bool active;

  // ---- Defaults for the spawned TaskItem
  TaskItemType itemType;
  LabourEntryMode labourEntryMode;

  // Estimated labour (choose hours OR dollars – same model as TaskItem)
  final Fixed? estimatedLabourHours; // 3dp
  final Money? estimatedLabourCost; // 2dp

  // Estimated materials (optional)
  final Money? estimatedMaterialUnitCost; // 2dp
  final Fixed? estimatedMaterialQuantity; // 3dp

  // Margin to apply to cost when computing charge
  final Percentage margin;

  // Suggested presentation/links
  final String url;

  // Default dimensions if this estimate usually has measurements
  final MeasurementType? measurementType;
  final Fixed dimension1; // 3dp
  final Fixed dimension2; // 3dp
  final Fixed dimension3; // 3dp
  final Units? units;

  // Optional supplier & default billing type suggestion
  final int? supplierId;
  final BillingType? preferredBillingType;

  // Suggested fixed charge override (rare: e.g. "Advertised from $70")
  final Money? suggestedCharge;

  // ----- Constructors -------------------------------------------------
  TaskEstimate._({
    required super.id,
    required super.createdDate,
    required super.modifiedDate,
    required this.name,
    required this.summary,
    required this.description,
    required this.assumption,
    required this.inclusions,
    required this.exclusions,
    required this.tags,
    required this.active,
    required this.itemType,
    required this.labourEntryMode,
    required this.estimatedLabourHours,
    required this.estimatedLabourCost,
    required this.estimatedMaterialUnitCost,
    required this.estimatedMaterialQuantity,
    required this.margin,
    required this.url,
    required this.measurementType,
    required this.dimension1,
    required this.dimension2,
    required this.dimension3,
    required this.units,
    required this.supplierId,
    required this.preferredBillingType,
    required this.suggestedCharge,
  }) : super();

  TaskEstimate.forInsert({
    required this.name,
    this.summary = '',
    this.description = '',
    this.assumption = '',
    this.inclusions = '',
    this.exclusions = '',
    this.tags = '',
    this.active = true,
    this.itemType = TaskItemType.labour,
    this.labourEntryMode = LabourEntryMode.hours,
    this.estimatedLabourHours,
    this.estimatedLabourCost,
    this.estimatedMaterialUnitCost,
    this.estimatedMaterialQuantity,
    Percentage? margin,
    this.url = '',
    MeasurementType? measurementType,
    Fixed? dimension1,
    Fixed? dimension2,
    Fixed? dimension3,
    Units? units,
    this.supplierId,
    this.preferredBillingType,
    this.suggestedCharge,
  }) : margin = margin ?? Percentage.zero,
       measurementType =
           measurementType ?? MeasurementType.defaultMeasurementType,
       dimension1 = dimension1 ?? Fixed.zero,
       dimension2 = dimension2 ?? Fixed.zero,
       dimension3 = dimension3 ?? Fixed.zero,
       units = units ?? Units.defaultUnits,
       super.forInsert();

  // ----- Mapping ------------------------------------------------------
  factory TaskEstimate.fromMap(Map<String, dynamic> map) => TaskEstimate._(
    id: map['id'] as int,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
    name: map['name'] as String,
    summary: map['summary'] as String? ?? '',
    description: map['description'] as String? ?? '',
    assumption: map['assumption'] as String? ?? '',
    inclusions: map['inclusions'] as String? ?? '',
    exclusions: map['exclusions'] as String? ?? '',
    tags: map['tags'] as String? ?? '',
    active: (map['active'] as int? ?? 1) == 1,
    itemType: TaskItemType.fromId(map['item_type_id'] as int),
    labourEntryMode: LabourEntryMode.fromString(
      map['labour_entry_mode'] as String,
    ),
    estimatedLabourHours: FixedEx.fromIntOrNull(
      map['estimated_labour_hours'] as int?,
    ),
    estimatedLabourCost: MoneyEx.moneyOrNull(
      map['estimated_labour_cost'] as int?,
    ),
    estimatedMaterialUnitCost: MoneyEx.moneyOrNull(
      map['estimated_material_unit_cost'] as int?,
    ),
    estimatedMaterialQuantity: FixedEx.fromIntOrNull(
      map['estimated_material_quantity'] as int?,
    ),
    margin: Percentage.fromInt(map['margin'] as int? ?? 0, decimalDigits: 3),
    url: map['url'] as String? ?? '',
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
    supplierId: map['supplier_id'] as int?,
    preferredBillingType: BillingType.fromName(
      map['preferred_billing_type'] as String?,
    ),
    suggestedCharge: MoneyEx.moneyOrNull(map['suggested_charge'] as int?),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'summary': summary,
    'description': description,
    'assumption': assumption,
    'inclusions': inclusions,
    'exclusions': exclusions,
    'tags': tags,
    'active': active ? 1 : 0,
    'item_type_id': itemType.id,
    'labour_entry_mode': labourEntryMode.toSqlString(),
    'estimated_labour_hours': estimatedLabourHours
        ?.threeDigits()
        .minorUnits
        .toInt(),
    'estimated_labour_cost': estimatedLabourCost
        ?.twoDigits()
        .minorUnits
        .toInt(),
    'estimated_material_unit_cost': estimatedMaterialUnitCost
        ?.twoDigits()
        .minorUnits
        .toInt(),
    'estimated_material_quantity': estimatedMaterialQuantity
        ?.threeDigits()
        .minorUnits
        .toInt(),
    'margin': margin.threeDigits().minorUnits.toInt(),
    'url': url,
    'measurement_type': measurementType?.name,
    'dimension1': dimension1.threeDigits().minorUnits.toInt(),
    'dimension2': dimension2.threeDigits().minorUnits.toInt(),
    'dimension3': dimension3.threeDigits().minorUnits.toInt(),
    'units': units?.name,
    'supplier_id': supplierId,
    'preferred_billing_type': preferredBillingType?.name,
    'suggested_charge': suggestedCharge?.twoDigits().minorUnits.toInt(),
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };

  TaskEstimate copyWith({
    String? name,
    String? summary,
    String? description,
    String? assumption,
    String? inclusions,
    String? exclusions,
    String? tags,
    bool? active,
    TaskItemType? itemType,
    LabourEntryMode? labourEntryMode,
    Fixed? estimatedLabourHours,
    Money? estimatedLabourCost,
    Money? estimatedMaterialUnitCost,
    Fixed? estimatedMaterialQuantity,
    Percentage? margin,
    String? url,
    MeasurementType? measurementType,
    Fixed? dimension1,
    Fixed? dimension2,
    Fixed? dimension3,
    Units? units,
    int? supplierId,
    BillingType? preferredBillingType,
    Money? suggestedCharge,
  }) => TaskEstimate._(
    id: id,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
    name: name ?? this.name,
    summary: summary ?? this.summary,
    description: description ?? this.description,
    assumption: assumption ?? this.assumption,
    inclusions: inclusions ?? this.inclusions,
    exclusions: exclusions ?? this.exclusions,
    tags: tags ?? this.tags,
    active: active ?? this.active,
    itemType: itemType ?? this.itemType,
    labourEntryMode: labourEntryMode ?? this.labourEntryMode,
    estimatedLabourHours: estimatedLabourHours ?? this.estimatedLabourHours,
    estimatedLabourCost: estimatedLabourCost ?? this.estimatedLabourCost,
    estimatedMaterialUnitCost:
        estimatedMaterialUnitCost ?? this.estimatedMaterialUnitCost,
    estimatedMaterialQuantity:
        estimatedMaterialQuantity ?? this.estimatedMaterialQuantity,
    margin: margin ?? this.margin,
    url: url ?? this.url,
    measurementType: measurementType ?? this.measurementType,
    dimension1: dimension1 ?? this.dimension1,
    dimension2: dimension2 ?? this.dimension2,
    dimension3: dimension3 ?? this.dimension3,
    units: units ?? this.units,
    supplierId: supplierId ?? this.supplierId,
    preferredBillingType: preferredBillingType ?? this.preferredBillingType,
    suggestedCharge: suggestedCharge ?? this.suggestedCharge,
  );

  // ----- Apply: spawn Task + TaskItem from catalog -------------------
  ///
  /// Creates a Task + TaskItem pair using this estimate as defaults.
  /// Use `hourlyRate` and `billingType` from the target Job.
  ///
  /// Notes:
  ///  - We set Task.name from estimate.name and copy assumption.
  ///  - We set TaskItem.charge if suggestedCharge is provided.
  ///  - For labour in "hours" mode we *do not* precompute charge;
  ///    normal TaskItem calc will apply margin later.
  ///
  (Task task, TaskItem item) toTaskAndItem({
    required int jobId,
    required BillingType billingType,
    required Money hourlyRate,
  }) {
    final task = Task.forInsert(
      jobId: jobId,
      name: name,
      description: summary.isNotEmpty ? summary : description,
      status: TaskStatus.awaitingApproval,
      assumption: assumption,
    );

    final item = TaskItem.forInsert(
      taskId: -1, // set by DAO once Task is persisted
      description: name,
      itemType: itemType,
      margin: margin,
      chargeMode: ChargeMode.calculated,
      measurementType:
          measurementType ?? MeasurementType.defaultMeasurementType,
      dimension1: dimension1,
      dimension2: dimension2,
      dimension3: dimension3,
      units: units ?? Units.defaultUnits,
      url: url,
      purpose: '',
      labourEntryMode: labourEntryMode,
      estimatedMaterialUnitCost: estimatedMaterialUnitCost,
      estimatedMaterialQuantity: estimatedMaterialQuantity,
      estimatedLabourCost: estimatedLabourCost,
      estimatedLabourHours: estimatedLabourHours,
      supplierId: supplierId,
      // If the template has a suggested "from $X" price, seed it.
      totalLineCharge: suggestedCharge,
    );

    return (task, item);
  }
}
