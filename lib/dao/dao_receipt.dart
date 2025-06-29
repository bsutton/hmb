/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/dao/dao_receipt.dart
import 'package:june/june.dart';

import '../entity/receipt.dart';
import 'dao.dart';

class ReceiptState extends JuneState {}

class DaoReceipt extends Dao<Receipt> {
  @override
  String get tableName => 'receipt';

  @override
  Receipt fromMap(Map<String, dynamic> map) => Receipt.fromMap(map);

  @override
  JuneStateCreator get juneRefresher => ReceiptState.new;

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
