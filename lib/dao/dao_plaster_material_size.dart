/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import '../entity/plaster_material_size.dart';
import 'dao.dart';

class DaoPlasterMaterialSize extends Dao<PlasterMaterialSize> {
  static const tableName = 'plaster_material_size';

  DaoPlasterMaterialSize() : super(tableName);

  @override
  PlasterMaterialSize fromMap(Map<String, dynamic> map) =>
      PlasterMaterialSize.fromMap(map);

  Future<List<PlasterMaterialSize>> getBySupplier(int supplierId) async {
    final rows = await withoutTransaction().query(
      tableName,
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'id ASC',
    );
    return toList(rows);
  }
}
