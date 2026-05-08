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

import '../entity/photo.dart';
import '../entity/receipt.dart';
import '../entity/task_item.dart';
import '../util/dart/exceptions.dart';
import '../util/dart/money_ex.dart';
import 'dao.dart';
import 'dao_photo.dart';
import 'dao_task_item.dart';
import 'dao_tool.dart';

class ReceiptJobAllocation {
  final int? id;
  final int receiptId;
  final int jobId;
  final Money amount;

  const ReceiptJobAllocation({
    required this.id,
    required this.receiptId,
    required this.jobId,
    required this.amount,
  });

  ReceiptJobAllocation.forInsert({
    required this.receiptId,
    required this.jobId,
    required this.amount,
  }) : id = null;

  factory ReceiptJobAllocation.fromMap(Map<String, Object?> map) =>
      ReceiptJobAllocation(
        id: map['id']! as int,
        receiptId: map['receipt_id']! as int,
        jobId: map['job_id']! as int,
        amount: MoneyEx.fromInt(map['amount'] as int?),
      );
}

class DaoReceipt extends Dao<Receipt> {
  static const tableName = 'receipt';
  DaoReceipt() : super(tableName);

  @override
  Receipt fromMap(Map<String, dynamic> map) => Receipt.fromMap(map);

  @override
  Future<int> insert(Receipt entity, [Transaction? transaction]) async {
    final id = await super.insert(entity, transaction);
    await _replaceWithSingleJobAllocation(entity, transaction);
    return id;
  }

  @override
  Future<int> update(Receipt entity, [Transaction? transaction]) async {
    final id = await super.update(entity, transaction);
    await _replaceWithSingleJobAllocation(entity, transaction);
    return id;
  }

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    final linkedCount = await DaoTool().countByReceiptId(id);
    if (linkedCount > 0) {
      throw HMBException(
        'Cannot delete this receipt while it is linked to a tool.',
      );
    }

    final linkedTaskItemCount = await countLinkedTaskItems(id);
    if (linkedTaskItemCount > 0) {
      throw HMBException(
        'Cannot delete this receipt while it is linked to task items.',
      );
    }

    final photos = await DaoPhoto().getByParent(id, ParentType.receipt);
    for (final photo in photos) {
      await DaoPhoto().delete(photo.id, transaction);
    }

    await withinTransaction(transaction).delete(
      'receipt_job_allocation',
      where: 'receipt_id = ?',
      whereArgs: [id],
    );

    return super.delete(id, transaction);
  }

  Future<void> _replaceWithSingleJobAllocation(
    Receipt receipt, [
    Transaction? transaction,
  ]) async {
    final executor = withinTransaction(transaction);
    await executor.delete(
      'receipt_job_allocation',
      where: 'receipt_id = ?',
      whereArgs: [receipt.id],
    );
    await executor.insert('receipt_job_allocation', {
      'receipt_id': receipt.id,
      'job_id': receipt.jobId,
      'amount': receipt.totalExcludingTax.minorUnits.toInt(),
      'created_date': DateTime.now().toIso8601String(),
      'modified_date': DateTime.now().toIso8601String(),
    });
  }

  Future<List<ReceiptJobAllocation>> getJobAllocations(int receiptId) async {
    final db = withoutTransaction();
    final rows = await db.query(
      'receipt_job_allocation',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
      orderBy: 'id ASC',
    );
    return rows.map(ReceiptJobAllocation.fromMap).toList();
  }

  Future<void> replaceJobAllocations(
    int receiptId,
    Iterable<ReceiptJobAllocation> allocations,
  ) async {
    final allocationList = allocations.toList();
    if (allocationList.isEmpty) {
      throw HMBException('At least one receipt job allocation is required.');
    }

    await db.transaction((txn) async {
      await txn.delete(
        'receipt_job_allocation',
        where: 'receipt_id = ?',
        whereArgs: [receiptId],
      );
      for (final allocation in allocationList) {
        final now = DateTime.now().toIso8601String();
        await txn.insert('receipt_job_allocation', {
          'receipt_id': receiptId,
          'job_id': allocation.jobId,
          'amount': allocation.amount.minorUnits.toInt(),
          'created_date': now,
          'modified_date': now,
        });
      }
    });
  }

  Future<int> countLinkedTaskItems(int receiptId) async {
    final db = withoutTransaction();
    final rows = await db.rawQuery(
      '''
SELECT COUNT(*) AS count
  FROM receipt_task_item
 WHERE receipt_id = ?
''',
      [receiptId],
    );
    return rows.first['count'] as int? ?? 0;
  }

  Future<List<int>> getLinkedTaskItemIds(int receiptId) async {
    final db = withoutTransaction();
    final rows = await db.rawQuery(
      '''
SELECT task_item_id
  FROM receipt_task_item
 WHERE receipt_id = ?
 ORDER BY task_item_id
''',
      [receiptId],
    );
    return rows.map((row) => row['task_item_id']).whereType<int>().toList();
  }

  Future<List<TaskItem>> getLinkedTaskItems(int receiptId) async {
    final ids = await getLinkedTaskItemIds(receiptId);
    return DaoTaskItem().getByIds(ids);
  }

  Future<void> replaceTaskItemLinks(
    int receiptId,
    Iterable<int> taskItemIds,
  ) async {
    await db.transaction((txn) async {
      await txn.delete(
        'receipt_task_item',
        where: 'receipt_id = ?',
        whereArgs: [receiptId],
      );
      for (final taskItemId in taskItemIds.toSet()) {
        final now = DateTime.now().toIso8601String();
        await txn.insert('receipt_task_item', {
          'receipt_id': receiptId,
          'task_item_id': taskItemId,
          'created_date': now,
          'modified_date': now,
        });
      }
    });
  }

  /// Filter receipts by optional criteria
  Future<List<Receipt>> getByFilter({
    String? supplierFilter,
    int? jobId,
    int? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? totalExcludingMin,
    int? totalExcludingMax,
  }) async {
    final db = withoutTransaction();
    final where = <String>[];
    final args = <dynamic>[];

    if (jobId != null) {
      where.add('job_id = ?');
      args.add(jobId);
    }
    if (supplierId != null) {
      where.add('supplier_id = ?');
      args.add(supplierId);
    }
    if (supplierFilter != null && supplierFilter.trim().isNotEmpty) {
      final like = '%${supplierFilter.trim()}%';
      where.add('''
supplier_id IN (
  SELECT id
  FROM supplier
  WHERE name LIKE ?
  OR description LIKE ?
  OR service LIKE ?
)
''');
      args.addAll([like, like, like]);
    }
    if (dateFrom != null) {
      where.add('receipt_date >= ?');
      args.add(dateFrom.toIso8601String());
    }
    if (dateTo != null) {
      where.add('receipt_date <= ?');
      args.add(dateTo.toIso8601String());
    }
    if (totalExcludingMin != null) {
      where.add('total_excluding_tax >= ?');
      args.add(totalExcludingMin);
    }
    if (totalExcludingMax != null) {
      where.add('total_excluding_tax <= ?');
      args.add(totalExcludingMax);
    }

    final maps = await db.query(
      tableName,
      where: where.isNotEmpty ? where.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'receipt_date desc',
    );
    return toList(maps);
  }
}
