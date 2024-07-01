// ignore: unnecessary_import
import 'package:fixed/fixed.dart';
import 'package:money2/money2.dart';

import '../util/money_ex.dart';
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
    this.invoiceLineId,
  }) : super();

  CheckListItem.forInsert({
    required this.checkListId,
    required this.description,
    required this.itemTypeId,
    required this.unitCost,
    required this.effortInHours,
    required this.quantity,
    this.completed = false, // Default to false for new entries
    this.billed = false, // Default to false for new entries
    this.invoiceLineId,
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
    this.invoiceLineId,
  }) : super.forUpdate();

  factory CheckListItem.fromMap(Map<String, dynamic> map) => CheckListItem(
        id: map['id'] as int,
        checkListId: map['check_list_id'] as int,
        description: map['description'] as String,
        itemTypeId: map['item_type_id'] as int,
        unitCost: MoneyEx.fromInt(map['unit_cost'] as int?),
        effortInHours: Fixed.fromInt(map['effort_in_hours'] as int? ?? 0),
        quantity: Fixed.fromInt(map['quantity'] as int? ?? 0),
        completed: map['completed'] == 1, // Convert from int (1/0) to bool
        billed: map['billed'] == 1, // Convert from int (1/0) to bool
        invoiceLineId: map['invoice_line_id'] as int?,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
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

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'check_list_id': checkListId,
        'description': description,
        'item_type_id': itemTypeId,
        'unit_cost': unitCost.minorUnits.toInt(),
        'effort_in_hours': effortInHours.minorUnits.toInt(),
        'quantity': quantity.minorUnits.toInt(),
        'completed': completed ? 1 : 0, // Convert bool to int (1/0)
        'billed': billed ? 1 : 0, // Convert bool to int (1/0)
        'invoice_line_id': invoiceLineId,
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
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
      );

  @override
  String toString() =>
      '''id: $id description: $description qty: $quantity cost: $unitCost completed: $completed billed: $billed''';
}
