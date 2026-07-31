/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import '../entity/custom_label_layout.dart';
import '../util/dart/measurement_type.dart';
import 'dao.dart';

class DaoCustomLabelLayout extends Dao<CustomLabelLayout> {
  static const tableName = 'custom_label_layout';

  DaoCustomLabelLayout() : super(tableName);

  @override
  CustomLabelLayout fromMap(Map<String, dynamic> map) =>
      CustomLabelLayout.fromMap(map);

  Future<List<CustomLabelLayout>> getForUnitSystem(
    PreferredUnitSystem unitSystem,
  ) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'unit_system = ?',
        whereArgs: [unitSystem.name],
        orderBy: 'name',
      ),
    );
  }

  Future<List<CustomLabelLayout>> getByFilter(String? filter) async {
    final db = withoutTransaction();
    if (filter == null || filter.trim().isEmpty) {
      return toList(await db.query(tableName, orderBy: 'name'));
    }

    return toList(
      await db.query(
        tableName,
        where: 'lower(name) like ?',
        whereArgs: ['%${filter.trim().toLowerCase()}%'],
        orderBy: 'name',
      ),
    );
  }

  Future<List<CustomLabelLayout>> getByFilterForUnitSystem(
    String? filter,
    PreferredUnitSystem unitSystem,
  ) async {
    final db = withoutTransaction();
    final trimmed = filter?.trim().toLowerCase();
    final hasFilter = trimmed != null && trimmed.isNotEmpty;
    return toList(
      await db.query(
        tableName,
        where: hasFilter
            ? 'unit_system = ? and lower(name) like ?'
            : 'unit_system = ?',
        whereArgs: hasFilter
            ? [unitSystem.name, '%$trimmed%']
            : [unitSystem.name],
        orderBy: 'name',
      ),
    );
  }
}
