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

import '../entity/receipt_line_item.dart';
import 'dao.dart';

class DaoReceiptLineItem extends Dao<ReceiptLineItem> {
  static const tableName = 'receipt_line_item';

  DaoReceiptLineItem() : super(tableName);

  @override
  ReceiptLineItem fromMap(Map<String, dynamic> map) =>
      ReceiptLineItem.fromMap(map);

  Future<List<ReceiptLineItem>> getByReceiptId(int receiptId) async {
    final rows = await withoutTransaction().query(
      tableName,
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
      orderBy: 'id ASC',
    );
    return toList(rows);
  }

  Future<void> replaceForReceipt(
    int receiptId,
    Iterable<ReceiptLineItem> items,
  ) async {
    await db.transaction((txn) async {
      await txn.delete(
        tableName,
        where: 'receipt_id = ?',
        whereArgs: [receiptId],
      );
      for (final item in items) {
        final values = ReceiptLineItem.forInsert(
          receiptId: receiptId,
          description: item.description,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          lineTotalExTax: item.lineTotalExTax,
          taxAmount: item.taxAmount,
          lineTotalIncTax: item.lineTotalIncTax,
          matchedTaskItemId: item.matchedTaskItemId,
          confidence: item.confidence,
          source: item.source,
        ).toMap()..remove('id');
        await txn.insert(tableName, values);
      }
    });
  }
}
