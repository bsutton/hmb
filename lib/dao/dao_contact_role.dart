import 'package:sqflite_common/sqlite_api.dart';

import '../entity/contact_role.dart';
import '../util/dart/exceptions.dart';
import 'dao.dart';
import 'dao_contact.dart';

class DaoContactRole {
  Database get _db => DatabaseHelper.instance.database;

  Future<List<ContactRole>> getAll([Transaction? transaction]) async =>
      (await (transaction ?? _db).query(
        'contact_role',
        orderBy: 'builtin DESC, name COLLATE NOCASE',
      )).map(ContactRole.fromMap).toList();

  Future<ContactRole?> getById(int? id, [Transaction? transaction]) async {
    if (id == null) {
      return null;
    }
    final rows = await (transaction ?? _db).query(
      'contact_role',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : ContactRole.fromMap(rows.first);
  }

  Future<int> create(String name, [Transaction? transaction]) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw HMBException('Enter a role name.');
    }
    return (transaction ?? _db).insert('contact_role', {'name': trimmed});
  }

  Future<void> rename(int id, String name) async {
    await _db.transaction((txn) async {
      final role = await getById(id, txn);
      if (role == null || role.builtin) {
        throw HMBException('Standard roles cannot be renamed.');
      }
      if (name.trim().isEmpty) {
        throw HMBException('Enter a role name.');
      }
      await txn.update(
        'contact_role',
        {'name': name.trim()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'contact',
        {'role_description': name.trim()},
        where: 'default_role_id = ?',
        whereArgs: [id],
      );
    });
    Dao.notifier(DaoContact());
  }

  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      final role = await getById(id, txn);
      if (role == null || role.builtin) {
        throw HMBException('Standard roles cannot be deleted.');
      }
      final used = await txn.rawQuery(
        'SELECT 1 FROM contact WHERE default_role_id = ? '
        'UNION ALL SELECT 1 FROM job_party WHERE role_id = ? LIMIT 1',
        [id, id],
      );
      if (used.isNotEmpty) {
        throw HMBException(
          'This role is in use. Reassign its contacts and jobs first.',
        );
      }
      await txn.delete('contact_role', where: 'id = ?', whereArgs: [id]);
    });
  }
}
