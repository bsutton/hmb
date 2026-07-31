/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:sqflite_common/sqlite_api.dart';
import 'package:strings/strings.dart';

import '../entity/mailing.dart';
import 'dao.dart';

class DaoMailing extends Dao<Mailing> {
  static const tableName = 'mailing';

  DaoMailing() : super(tableName);

  @override
  Mailing fromMap(Map<String, dynamic> map) => Mailing.fromMap(map);

  Future<List<Mailing>> getByFilter(String? filter) async {
    final db = withoutTransaction();
    if (Strings.isBlank(filter)) {
      return getAll(orderByClause: 'modifiedDate desc');
    }
    final like = '%${filter!.trim()}%';
    return toList(
      await db.query(
        tableName,
        where: 'name like ? or notes like ?',
        whereArgs: [like, like],
        orderBy: 'modifiedDate desc',
      ),
    );
  }

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);
    await db.delete(
      'mailing_recipient',
      where: 'mailing_id = ?',
      whereArgs: [id],
    );
    return super.delete(id, transaction);
  }
}
