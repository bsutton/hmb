import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../entity/entity.g.dart';
import '../util/util.g.dart';
import 'dao.dart';

class DaoTaskItem extends Dao<TaskItem> {
  @override
  TaskItem fromMap(Map<String, dynamic> map) => TaskItem.fromMap(map);

  @override
  String get tableName => 'task_item';

  Future<List<TaskItem>> getByTask(int? taskId) async {
    final db = withoutTransaction();

    if (taskId == null) {
      return [];
    }
    return toList(
      await db.rawQuery(
        '''
select ti.* 
from task_item ti
where ti.task_id = ?
''',
        [taskId],
      ),
    );
  }

  Future<void> deleteByTask(int id, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);

    await db.rawDelete(
      '''
DELETE FROM task_item
WHERE task_id = ?
''',
      [id],
    );
  }

  Future<void> markAsCompleted(
    BillingType billingType,
    TaskItem item,
    Money unitCost,
    Fixed quantity,
  ) async {
    item
      ..completed = true
      ..actualMaterialUnitCost = unitCost
      ..actualMaterialQuantity = quantity
      ..setCharge(item.calcMaterialCharges(billingType));

    await update(item);
  }

  Future<void> markAsBilled(TaskItem item, int invoiceLineId) async {
    final updatedItem = item.copyWith(
      billed: true,
      invoiceLineId: invoiceLineId,
    );
    await update(updatedItem);
  }

  Future<List<TaskItem>> getIncompleteItems() async {
    final db = withoutTransaction();

    return toList(
      await db.rawQuery('''
select ti.* 
from task_item ti
where ti.completed = 0
'''),
    );
  }

  Future<void> markNotBilled(int invoiceLineId) async {
    final db = withoutTransaction();
    await db.update(
      tableName,
      {'billed': 0, 'invoice_line_id': null},
      where: 'invoice_line_id=?',
      whereArgs: [invoiceLineId],
    );
  }

  Future<List<TaskItem>> getPackingItems({List<Job>? jobs}) async {
    final db = withoutTransaction();

    // Base query for retrieving packing items
    var query = '''
SELECT ti.* 
FROM task_item ti
JOIN task_item_type tit
  ON ti.item_type_id = tit.id
JOIN task t
  ON ti.task_id = t.id
JOIN job j
  ON t.job_id = j.id
JOIN job_status js
  ON j.job_status_id = js.id
WHERE (tit.name = 'Materials - stock' 
OR tit.name = 'Tools - own') 
AND ti.completed = 0
AND js.name NOT IN ('Prospecting', 'Rejected', 'On Hold', 'Awaiting Payment')
''';

    final parameters = <int>[];
    if (jobs != null && jobs.isNotEmpty) {
      // Add filtering for specific jobs if provided
      final jobIds = jobs.map((job) => job.id).toList();
      final placeholders = List.filled(jobIds.length, '?').join(',');

      query += ' AND j.id IN ($placeholders)';
      parameters.addAll(jobIds);
    }

    return toList(await db.rawQuery(query, parameters));
  }

  Future<List<TaskItem>> getShoppingItems({
    List<Job>? jobs,
    Supplier? supplier,
  }) async {
    final db = withoutTransaction();

    // Build conditions for filtering jobs and suppliers
    final jobIds = jobs?.map((job) => job.id).toList() ?? [];
    final jobCondition =
        jobIds.isNotEmpty
            ? 'AND j.id IN (${jobIds.map((_) => '?').join(",")})'
            : '';
    final supplierCondition = supplier != null ? 'AND ti.supplier_id = ?' : '';

    // Combine the query with optional filters
    final query = '''
SELECT ti.* 
FROM task_item ti
JOIN task_item_type tit ON ti.item_type_id = tit.id
JOIN task t ON ti.task_id = t.id
JOIN job j ON t.job_id = j.id
JOIN job_status js ON j.job_status_id = js.id
WHERE (tit.name = 'Materials - buy' OR tit.name = 'Tools - buy')
AND ti.completed = 0
AND js.name NOT IN ('Prospecting', 'Rejected', 'On Hold', 'Awaiting Payment')
$jobCondition
$supplierCondition
''';

    final parameters = <dynamic>[];
    if (jobIds.isNotEmpty) {
      parameters.addAll(jobIds);
    }
    if (supplier != null) {
      parameters.add(supplier.id);
    }

    return toList(await db.rawQuery(query, parameters));
  }

  Money calculateCharge({
    required int? itemTypeId,
    required Percentage margin,
    required LabourEntryMode labourEntryMode,
    required Fixed estimatedLabourHours,
    required Money hourlyRate,
    required Money estimatedMaterialUnitCost,
    required Money estimatedLabourCost,
    required Fixed estimatedMaterialQuantity,
    required Money charge,
  }) {
    Money? estimatedCost;

    switch (itemTypeId) {
      case 1:
      case 2:
      case 3:
      case 4:
        {
          final quantity = estimatedMaterialQuantity;
          estimatedCost = estimatedMaterialUnitCost.multiplyByFixed(quantity);
          charge = estimatedCost.plusPercentage(margin);
        }
      case 5:
        {
          if (labourEntryMode == LabourEntryMode.hours) {
            estimatedCost = hourlyRate.multiplyByFixed(estimatedLabourHours);
          } else {
            estimatedCost = estimatedLabourCost;
          }
          charge = estimatedCost.plusPercentage(margin);
        }
    }

    return charge;
  }

  @override
  JuneStateCreator get juneRefresher => TaskItemState.new;

  Future<List<TaskItem>> getPurchasedItems({
    required DateTime since,
    required List<Job> jobs,
    Supplier? supplier,
  }) async {
    final db = withoutTransaction();

    // Base query for retrieving purchased items (Materials - buy, Tools - buy)
    final sql = StringBuffer('''
SELECT ti.*
FROM task_item ti
JOIN task_item_type tit ON ti.item_type_id = tit.id
JOIN task t ON ti.task_id = t.id
JOIN job j ON t.job_id = j.id
WHERE (tit.name = 'Materials - buy' OR tit.name = 'Tools - buy')
  AND ti.completed = 1
  AND ti.modified_date >= ?
''');

    // Collect parameters, starting with the "since" timestamp
    final params = <dynamic>[since.toIso8601String()];

    // If jobs were provided, filter by those job IDs
    if (jobs.isNotEmpty) {
      final placeholders = List.filled(jobs.length, '?').join(',');
      sql.write(' AND j.id IN ($placeholders)');
      params.addAll(jobs.map((j) => j.id));
    }

    // If a supplier was provided, filter by that supplier ID
    if (supplier != null) {
      sql.write(' AND ti.supplier_id = ?');
      params.add(supplier.id);
    }

    // Execute and map to TaskItem instances
    final rows = await db.rawQuery(sql.toString(), params);
    return toList(rows);
  }

  Future<List<TaskItem>> getReturnableItems({
    List<Job>? jobs,
    Supplier? supplier,
  }) async {
    final db = withoutTransaction();

    // Base query for returnable purchased items
    final sql = StringBuffer('''
SELECT ti.*
FROM task_item ti
JOIN task_item_type tit ON ti.item_type_id = tit.id
JOIN task t ON ti.task_id = t.id
JOIN job j ON t.job_id = j.id
WHERE (tit.name = 'Materials - buy' OR tit.name = 'Tools - buy')
  AND ti.completed = 1
''');

    final params = <dynamic>[];

    // Filter by specific jobs if provided
    if (jobs != null && jobs.isNotEmpty) {
      final placeholders = List.filled(jobs.length, '?').join(',');
      sql.write(' AND j.id IN ($placeholders)');
      params.addAll(jobs.map((j) => j.id));
    }

    // Filter by supplier if provided
    if (supplier != null) {
      sql.write(' AND ti.supplier_id = ?');
      params.add(supplier.id);
    }

    // Order by most recently completed first
    sql.write(' ORDER BY ti.modified_date DESC');

    final rows = await db.rawQuery(sql.toString(), params);
    return toList(rows);
  }

  /// In DaoTaskItem (just below your other “mark…” methods)

  /// Marks a completed TaskItem as returned:
  ///  - sets returned flag
  ///  - records how many units were returned
  ///  - records the refund per unit
  ///  - timestamps the return
  Future<void> markAsReturned(
    int taskItemId,
    Fixed returnQuantity,
    Money returnUnitPrice,
  ) async {
    final db = withoutTransaction();
    final now = DateTime.now().toIso8601String();

    await db.update(
      tableName,
      {
        'returned': 1,
        'return_quantity': returnQuantity.threeDigits().minorUnits.toInt(),
        'return_unit_price': returnUnitPrice.twoDigits().minorUnits.toInt(),
        'return_date': now,
        'modified_date': now,
      },
      where: 'id = ?',
      whereArgs: [taskItemId],
    );
  }
}

class TaskItemState extends JuneState {
  TaskItemState();
}
