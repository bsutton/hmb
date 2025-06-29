/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

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

  /// shopping items
  Future<List<TaskItem>> getShoppingItems({
    List<Job>? jobs,
    int? supplierId,
  }) async {
    final db = withoutTransaction();

    // Build job‐filter clause
    final jobIds = jobs?.map((j) => j.id).toList() ?? [];
    final jobClause = jobIds.isNotEmpty
        ? 'AND j.id IN (${List.filled(jobIds.length, '?').join(',')})'
        : '';

    final supplierClause = supplierId != null ? 'AND ti.supplier_id = ?' : '';

    final sql =
        '''
SELECT ti.*
  FROM task_item ti
  JOIN task_item_type tit ON ti.item_type_id = tit.id
  JOIN task t               ON ti.task_id       = t.id
  JOIN job j                ON t.job_id         = j.id
  JOIN job_status js        ON j.job_status_id  = js.id
 WHERE (tit.name = 'Materials - buy' OR tit.name = 'Tools - buy')
   AND ti.completed = 0
   AND ti.is_return = 0
   AND js.name NOT IN ( 'Rejected', 'On Hold')
   $jobClause
   $supplierClause
''';

    final params = <dynamic>[];
    if (jobIds.isNotEmpty) {
      params.addAll(jobIds);
    }
    if (supplierId != null) {
      params.add(supplierId);
    }

    return toList(await db.rawQuery(sql, params));
  }

  /// Calculate charge
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

  /// Items that have been purchased but not returned.
  Future<List<TaskItem>> getPurchasedItems({
    required DateTime since,
    required List<Job> jobs,
    int? supplierId,
  }) async {
    final db = withoutTransaction();

    final sql = StringBuffer('''
SELECT ti.*
  FROM task_item ti
  JOIN task_item_type tit ON ti.item_type_id = tit.id
  JOIN task t               ON ti.task_id       = t.id
  JOIN job j                ON t.job_id         = j.id
 WHERE (tit.name = 'Materials - buy' OR tit.name = 'Tools - buy')
   AND ti.completed = 1
   AND ti.is_return = 0
   AND ti.modified_date >= ?
   -- exclude any purchase that has been returned
   AND NOT EXISTS (
     SELECT 1
       FROM task_item r
      WHERE r.source_task_item_id = ti.id
   )
''');

    final params = <dynamic>[since.toIso8601String()];

    if (jobs.isNotEmpty) {
      final placeholders = List.filled(jobs.length, '?').join(',');
      sql.write(' AND j.id IN ($placeholders)');
      params.addAll(jobs.map((j) => j.id));
    }
    if (supplierId != null) {
      sql.write(' AND ti.supplier_id = ?');
      params.add(supplierId);
    }

    sql.write(' ORDER BY ti.modified_date DESC');
    final rows = await db.rawQuery(sql.toString(), params);
    return toList(rows);
  }

  /// “Returned” tab (items that have already been returned)
  Future<List<TaskItem>> getReturnedItems({
    List<Job>? jobs,
    int? supplierId,
  }) async {
    final db = withoutTransaction();

    final sql = StringBuffer('''
SELECT ti.*
  FROM task_item ti
  JOIN task_item_type tit ON ti.item_type_id = tit.id
  JOIN task t               ON ti.task_id       = t.id
  JOIN job j                ON t.job_id         = j.id
 WHERE ti.is_return = 1
''');

    final params = <dynamic>[];

    // Optional job filter
    if (jobs != null && jobs.isNotEmpty) {
      final placeholders = List.filled(jobs.length, '?').join(',');
      sql.write(' AND j.id IN ($placeholders)');
      params.addAll(jobs.map((j) => j.id));
    }

    // Optional supplier filter
    if (supplierId != null) {
      sql.write(' AND ti.supplier_id = ?');
      params.add(supplierId);
    }

    // Most recent returns first
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
    int originalId,
    Fixed returnQuantity,
    Money returnUnitPrice,
  ) async {
    final db = withoutTransaction();

    // 1. Fetch the original
    final rows = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [originalId],
    );
    if (rows.isEmpty) {
      throw StateError('No TaskItem found with id=$originalId');
    }
    final original = TaskItem.fromMap(rows.first);

    // 2. Build and insert the return row
    final returnItem = original.forReturn(returnQuantity, returnUnitPrice);
    await insert(returnItem);
  }

  /// True if the passsed [taskItemId] has been returned.
  Future<bool> wasReturned(int taskItemId) async {
    final db = withoutTransaction();
    final rows = await db.rawQuery(
      'SELECT 1 FROM task_item WHERE source_task_item_id = ? LIMIT 1',
      [taskItemId],
    );
    return rows.isNotEmpty;
  }
}

class TaskItemState extends JuneState {
  TaskItemState();
}
