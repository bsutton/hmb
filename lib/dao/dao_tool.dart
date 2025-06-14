import 'package:june/june.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:strings/strings.dart';

import '../entity/entity.g.dart';
import 'dao.dart';
import 'dao_photo.dart';

class DaoTool extends Dao<Tool> {
  @override
  String get tableName => 'tool';

  @override
  Tool fromMap(Map<String, dynamic> map) => Tool.fromMap(map);

  Future<List<Tool>> getAllTools() async {
    final db = withoutTransaction();
    final List<Map<String, dynamic>> maps = await db.query(tableName);

    return maps.map(fromMap).toList();
  }

  Future<List<Tool>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    if (Strings.isBlank(filter)) {
      return getAll(orderByClause: 'name');
    }

    final like = '''%$filter%''';
    return toList(
      await db.rawQuery(
        '''
select t.* 
from tool t
join category c
on t.categoryId = c.id
where t.name like ?
or c.name like ?
or t.serialNumber like ?
or t.description like ?
order by t.name
''',
        [like, like, like, like],
      ),
    );
  }

  Future<void> insertTool(Tool tool, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    await db.insert(tableName, tool.toMap());
  }

  Future<void> updateTool(Tool tool, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    await db.update(
      tableName,
      tool.toMap(),
      where: 'id = ?',
      whereArgs: [tool.id],
    );
  }

  Future<void> deleteTool(int id, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);

    final photos = await DaoPhoto().getByParent(id, ParentType.tool);
    for (final photo in photos) {
      await DaoPhoto().delete(photo.id);
    }

    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  JuneStateCreator get juneRefresher => DbToolChanged.new;
}

class DbToolChanged extends JuneState {
  DbToolChanged();
}
