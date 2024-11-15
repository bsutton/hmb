import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/_index.g.dart';
import 'dao.dart';
import 'dao_check_list_item_check_list.dart';

class DaoCheckListItem extends Dao<CheckListItem> {
  Future<void> createTable(Database db, int version) async {}

  @override
  CheckListItem fromMap(Map<String, dynamic> map) => CheckListItem.fromMap(map);

  @override
  String get tableName => 'check_list_item';

  Future<List<CheckListItem>> getByCheckList(CheckList checklist) async {

    final data = await withoutTransaction().rawQuery('''
select cli.* 
from check_list cl
join check_list_item cli
  on cl.id = cli.check_list_id
where cl.id =? 
''', [checklist.id]);

    return toList(data);
  }

  Future<List<CheckListItem>> getItemsByTask(int? taskId) async {
    final db = withoutTransaction();

    if (taskId == null) {
      return [];
    }
    final data = await db.rawQuery('''
select cli.* 
from check_list_item cli
join check_list cl
  on cli.check_list_id = cl.id
join task_check_list jc
  on cl.id = jc.check_list_id
join task jo
  on jc.task_id = jo.id
where jo.id =? 
''', [taskId]);

    return toList(data);
  }

  Future<void> deleteFromCheckList(
      CheckListItem checklistitem, CheckList checklist) async {
    await DaoCheckListItemCheckList().deleteJoin(checklist, checklistitem);
    await delete(checklistitem.id);
  }

  Future<void> insertForCheckList(
      CheckListItem checklistitem, CheckList checklist) async {
    await insert(checklistitem);
    await DaoCheckListItemCheckList().insertJoin(checklistitem, checklist);
  }

  Future<void> markAsCompleted(
      CheckListItem item, Money unitCost, Fixed quantity) async {
    item
      ..actualMaterialUnitCost = unitCost
      ..actualMaterialQuantity = quantity
      ..charge = item.calcMaterialCost()
      ..completed = true;

    await update(item);
  }

  /// Marks the item as billed and links it to the invoice line it was
  /// billed on.
  Future<void> markAsBilled(CheckListItem item, int invoiceLineId) async {
    final updatedItem =
        item.copyWith(billed: true, invoiceLineId: invoiceLineId);
    await DaoCheckListItem().update(updatedItem);
  }

  Future<List<CheckListItem>> getIncompleteItems() async {
    final db = withoutTransaction();

    final data = await db.rawQuery('''
select cli.* 
from check_list_item cli
where cli.completed = 0
''');

    return toList(data);
  }

  Future<void> deleteByChecklist(CheckList checklist) async {
    final db = withoutTransaction();

    await db.rawDelete('''

DELETE FROM check_list_item
WHERE check_list_id IN (
  SELECT cl.id FROM check_list cl
  WHERE cl.id = ?
)
''', [checklist.id]);
  }

  Future<List<CheckListItem>> getByTask(int taskId) async {
    final db = withoutTransaction();

    final data = await db.rawQuery('''
select cli.* 
from task t
join task_check_list tc
  on t.id = tc.task_id
join check_list cl
  on tc.check_list_id = cl.id
join check_list_item cli
  on cl.id = cli.check_list_id
where t.id =? 
''', [taskId]);

    return toList(data);
  }

  @override
  JuneStateCreator get juneRefresher => CheckListItemState.new;

  Future<void> markNotBilled(int invoiceLineId) async {
    final db = withoutTransaction();
    await db.update(tableName, {'billed': 0, 'invoice_line_id': null},
        where: 'invoice_line_id=?', whereArgs: [invoiceLineId]);
  }

  /// Get items that need to be packed, optionally filtered by a list of jobs.
  Future<List<CheckListItem>> getPackingItems({List<Job>? jobs}) async {
    final db = withoutTransaction();

    var query = '''
select cli.* 
from check_list_item cli
join check_list_item_type clit
  on cli.item_type_id = clit.id
join check_list cl
  on cl.id = cli.check_list_id
join task_check_list tcl
  on cl.id = tcl.check_list_id
join `task` t
  on tcl.task_id = t.id
join job j
  on t.job_id = j.id
join job_status js
  on j.job_status_id = js.id
where (clit.name = 'Materials - stock' 
or clit.name = 'Tools - own') 
and cli.completed = 0
and js.name != 'Prospecting'
and js.name != 'Rejected'
and js.name != 'On Hold'
and js.name != 'Awaiting Payment'
''';

    // If a list of jobs is provided, add an "IN" clause to filter
    //by the job IDs
    final parameters = <int>[];
    if (jobs != null && jobs.isNotEmpty) {
      // Generate placeholders for the job IDs
      final jobIds = jobs.map((job) => job.id).toList();
      final placeholders = List.filled(jobIds.length, '?').join(',');

      query += ' and j.id IN ($placeholders)';
      parameters.addAll(jobIds);
    }

    // Execute the query with or without the job filter
    final data = await db.rawQuery(query, parameters);

    return toList(data);
  }

  /// Get items that need to be purchased..
  Future<List<CheckListItem>> getShoppingItems(
      {List<Job>? jobs, Supplier? supplier}) async {
    final db = withoutTransaction();
    final jobIds = jobs?.map((job) => job.id).toList() ?? [];
    final jobCondition =
        jobIds.isNotEmpty ? 'AND j.id IN (${jobIds.join(",")})' : '';
    final supplierCondition =
        supplier != null ? 'AND cli.supplier_id = ${supplier.id}' : '';

    final data = await db.rawQuery('''
    SELECT cli.* 
    FROM check_list_item cli
    JOIN check_list_item_type clit ON cli.item_type_id = clit.id
    JOIN check_list cl ON cl.id = cli.check_list_id
    JOIN task_check_list tcl ON cl.id = tcl.check_list_id
    JOIN task t ON tcl.task_id = t.id
    JOIN job j ON t.job_Id = j.id
    JOIN job_status js ON j.job_status_id = js.id
    WHERE (clit.name = 'Materials - buy' OR clit.name = 'Tools - buy')
    AND cli.completed = 0
    AND js.name NOT IN ('Prospecting', 'Rejected', 'On Hold', 'Awaiting Payment')
    $jobCondition
    $supplierCondition
    ''');

    return toList(data);
  }

  /// Returns the caculated charge.
  Money calculateCharge(
      {required int? itemTypeId,
      required Fixed margin,
      required LabourEntryMode labourEntryMode,
      required Fixed estimatedLabourHours,
      required Money hourlyRate,
      required Money estimatedMaterialUnitCost,
      required Money estimatedLabourCost,
      required Fixed estimatedMaterialQuantity,
      required Money charge}) {
    Money? estimatedCost;

    // Determine the estimated cost based on item type
    switch (itemTypeId) {
      case 1: // Materials - stock
      case 2: // Materials - buy
      case 3: // Tools - buy
      case 4: // Tools - own
        {
          final quantity = estimatedMaterialQuantity;
          estimatedCost = estimatedMaterialUnitCost.multiplyByFixed(quantity);
          charge = estimatedCost
              .multiplyByFixed(Fixed.one + (margin / Fixed.fromInt(100)));
        }
      // Labour
      case 5:
        {
          if (labourEntryMode == LabourEntryMode.hours) {
            estimatedCost = hourlyRate.multiplyByFixed(estimatedLabourHours);
          } else {
            estimatedCost = estimatedLabourCost;
          }
          charge = estimatedCost
              .multiplyByFixed(Fixed.one + (margin / Fixed.fromInt(100)));
        }
    }

    return charge;
  }
}

/// Used to notify the UI that the time entry has changed.
class CheckListItemState extends JuneState {
  CheckListItemState();
}
