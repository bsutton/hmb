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

import '../entity/tax_code.dart';
import 'dao.dart';

class DaoTaxCode extends Dao<TaxCode> {
  static const tableName = 'tax_code';

  DaoTaxCode() : super(tableName);

  @override
  TaxCode fromMap(Map<String, dynamic> map) => TaxCode.fromMap(map);

  Future<List<TaxCode>> getBySchemeId(
    int taxSchemeId, {
    DateTime? effectiveOn,
  }) async {
    final where = StringBuffer('tax_scheme_id = ?');
    final args = <Object?>[taxSchemeId];
    if (effectiveOn != null) {
      final effectiveDate = _dateOnly(effectiveOn);
      where.write(' AND effective_from <= ?');
      args.add(effectiveDate);
      where.write(' AND (effective_to IS NULL OR effective_to >= ?)');
      args.add(effectiveDate);
    }

    final rows = await withoutTransaction().query(
      tableName,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'is_default_sales DESC, display_name ASC',
    );
    return toList(rows);
  }

  Future<TaxCode?> getDefaultSalesCode(
    int taxSchemeId, {
    DateTime? effectiveOn,
  }) => _getDefaultCode(
    taxSchemeId,
    defaultColumn: 'is_default_sales',
    effectiveOn: effectiveOn,
  );

  Future<TaxCode?> getDefaultPurchaseCode(
    int taxSchemeId, {
    DateTime? effectiveOn,
  }) => _getDefaultCode(
    taxSchemeId,
    defaultColumn: 'is_default_purchase',
    effectiveOn: effectiveOn,
  );

  Future<TaxCode?> _getDefaultCode(
    int taxSchemeId, {
    required String defaultColumn,
    DateTime? effectiveOn,
  }) async {
    final where = StringBuffer('tax_scheme_id = ? AND $defaultColumn = 1');
    final args = <Object?>[taxSchemeId];
    if (effectiveOn != null) {
      final effectiveDate = _dateOnly(effectiveOn);
      where.write(' AND effective_from <= ?');
      args.add(effectiveDate);
      where.write(' AND (effective_to IS NULL OR effective_to >= ?)');
      args.add(effectiveDate);
    }

    final rows = await withoutTransaction().query(
      tableName,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'effective_from DESC, id ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : fromMap(rows.first);
  }
}

String _dateOnly(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
