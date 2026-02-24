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

import '../entity/receipt.dart';
import '../entity/photo.dart';
import '../util/dart/exceptions.dart';
import 'dao.dart';
import 'dao_photo.dart';
import 'dao_tool.dart';

class DaoReceipt extends Dao<Receipt> {
  static const tableName = 'receipt';
  DaoReceipt() : super(tableName);

  @override
  Receipt fromMap(Map<String, dynamic> map) => Receipt.fromMap(map);

  @override
  Future<int> delete(int id, [transaction]) async {
    final linkedCount = await DaoTool().countByReceiptId(id);
    if (linkedCount > 0) {
      throw HMBException(
        'Cannot delete this receipt while it is linked to a tool.',
      );
    }

    final photos = await DaoPhoto().getByParent(id, ParentType.receipt);
    for (final photo in photos) {
      await DaoPhoto().delete(photo.id, transaction);
    }

    return super.delete(id, transaction);
  }

  /// Filter receipts by optional criteria
  Future<List<Receipt>> getByFilter({
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
