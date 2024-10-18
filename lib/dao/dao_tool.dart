import '../entity/tool.dart';
import 'dao.dart';

class DaoTool extends Dao<Tool> {
  @override
  String get tableName => 'tool';

  @override
  Tool fromMap(Map<String, dynamic> map) => Tool.fromMap(map);

  Future<List<Tool>> getAllTools() async {
    final db = getDb();
    final List<Map<String, dynamic>> maps = await db.query(tableName);

    return maps.map(fromMap).toList();
  }

  Future<void> insertTool(Tool tool) async {
    final db = getDb();
    await db.insert(tableName, tool.toMap());
  }

  Future<void> updateTool(Tool tool) async {
    final db = getDb();
    await db.update(
      tableName,
      tool.toMap(),
      where: 'id = ?',
      whereArgs: [tool.id],
    );
  }

  Future<void> deleteTool(int id) async {
    final db = getDb();
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }
}
