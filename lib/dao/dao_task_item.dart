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

import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../entity/entity.g.dart';
import '../util/dart/money_ex.dart';
import 'dao.dart';

class DaoTaskItem extends Dao<TaskItem> {
  static const tableName = 'task_item';
  DaoTaskItem() : super(tableName);

  @override
  TaskItem fromMap(Map<String, dynamic> map) => TaskItem.fromMap(map);

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

  Future<void> markAsCompleted({
    required TaskItem item,
    required Money materialUnitCost,
    required Fixed materialQuantity,
  }) async {
    item
      ..completed = true
      ..setActualCosts(
        actualMaterialQuantity: materialQuantity,
        actualMaterialUnitCost: materialUnitCost,
      );

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

  Future<List<TaskItem>> getByInvoiceLineIds(List<int> invoiceLineIds) async {
    if (invoiceLineIds.isEmpty) {
      return [];
    }
    final db = withoutTransaction();
    final placeholders = List.filled(invoiceLineIds.length, '?').join(',');
    final rows = await db.rawQuery('''
SELECT ti.*
  FROM task_item ti
 WHERE ti.invoice_line_id IN ($placeholders)
''', invoiceLineIds);
    return toList(rows);
  }

  Future<List<TaskItem>> getByIds(List<int> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    final db = withoutTransaction();
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery('''
SELECT ti.*
  FROM task_item ti
 WHERE ti.id IN ($placeholders)
''', ids);
    return toList(rows);
  }

  /// Get items that need to be packed.
  Future<List<TaskItem>> getPackingItems({
    required bool showPreScheduledJobs,
    required bool showPreApprovedTask,
    List<Job>? jobs,
  }) async {
    final db = withoutTransaction();

    const baseQuery = '''
      SELECT ti.*
        FROM task_item ti
        JOIN task t ON ti.task_id = t.id
        JOIN job j ON t.job_id = j.id
    ''';

    final conditions = <String>[
      '''
      ti.item_type_id IN (${TaskItemType.materialsStock.id}, 
          ${TaskItemType.toolsOwn.id}, 
          ${TaskItemType.consumablesStock.id})''',
      'ti.completed = 0',
    ];
    final parameters = <Object>[];

    // ————— Job status filtering —————
    final allowedStatusIds = <String>[
      JobStatus.inProgress.id,
      JobStatus.scheduled.id,
    ];
    if (showPreScheduledJobs) {
      allowedStatusIds.addAll(
        JobStatus.values
            .where((s) => s.stage == JobStatusStage.preStart)
            .map((s) => s.id),
      );
    }
    final statusPlaceholders = List.filled(
      allowedStatusIds.length,
      '?',
    ).join(', ');
    conditions.add('j.status_id IN ($statusPlaceholders)');
    parameters.addAll(allowedStatusIds);

    // ————— Task status filtering —————
    // when showPreApprovedTask==false, exclude pre-approval & to-be-scheduled
    if (!showPreApprovedTask) {
      final excludeIds = <int>[TaskStatus.awaitingApproval.id];
      final excludePlaceholders = List.filled(
        excludeIds.length,
        '?',
      ).join(', ');
      conditions.add('t.task_status_id NOT IN ($excludePlaceholders)');
      parameters.addAll(excludeIds);
    }

    // ————— Optional job ID filtering —————
    if (jobs != null && jobs.isNotEmpty) {
      final jobIds = jobs.map((job) => job.id).toList();
      final jobPlaceholders = List.filled(jobIds.length, '?').join(', ');
      conditions.add('j.id IN ($jobPlaceholders)');
      parameters.addAll(jobIds);
    }

    // assemble final query & execute
    final query = '$baseQuery WHERE ${conditions.join(' AND ')}';
    final results = await db.rawQuery(query, parameters);
    return toList(results);
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
  JOIN task t               ON ti.task_id       = t.id
  JOIN job j                ON t.job_id         = j.id
 WHERE (ti.item_type_id = ${TaskItemType.materialsBuy.id}
 OR ti.item_type_id = ${TaskItemType.consumablesBuy.id}
  OR ti.item_type_id = ${TaskItemType.toolsBuy.id}
  )
   AND ti.completed = 0
   AND ti.is_return = 0
   AND j.status_id NOT IN ( '${JobStatus.rejected.id}', '${JobStatus.onHold.id}')
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
    required TaskItemType itemType,
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

    switch (itemType) {
      case TaskItemType.materialsBuy:
      case TaskItemType.materialsStock:
      case TaskItemType.toolsBuy:
      case TaskItemType.toolsOwn:
      case TaskItemType.consumablesStock:
      case TaskItemType.consumablesBuy:
        {
          final quantity = estimatedMaterialQuantity;
          estimatedCost = estimatedMaterialUnitCost.multiplyByFixed(quantity);
          charge = estimatedCost.plusPercentage(margin);
        }
      case TaskItemType.labour:
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
  JOIN task t               ON ti.task_id       = t.id
  JOIN job j                ON t.job_id         = j.id
 WHERE (ti.item_type_id = 1 -- 'Materials - buy' 
 OR ti.item_type_id = 3 -- 'Tools - buy'
 )
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
    final taskItem = await DaoTaskItem().getById(originalId);

    // 2. Build and insert the return row
    final returnItem = taskItem!.forReturn(returnQuantity, returnUnitPrice);
    await insert(returnItem);
  }

  /// True if a return TaskItem exists whose source points to [taskItemId].
  Future<bool> wasReturned(int taskItemId) async {
    final db = withoutTransaction();
    final rows = await db.rawQuery(
      '''
SELECT 1
  FROM task_item
 WHERE source_task_item_id = ?
 LIMIT 1
''',
      [taskItemId],
    );
    return rows.isNotEmpty;
  }
}
