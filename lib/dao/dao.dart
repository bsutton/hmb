import 'package:june/june.dart';

import '../database/management/database_helper.dart';
import '../entity/entity.dart';
import 'dao_base.dart';

export '../database/management/database_helper.dart';

typedef JuneStateCreator = JuneState Function();

abstract class Dao<T extends Entity<T>> extends DaoBase<T> {
  Dao() : super(DatabaseHelper.instance.database, _notifier) {
    super.tableName = tableName;
    super.mapper = fromMap;
  }

  static void _notifier(DaoBase dao) {
    (dao as Dao)._notify();
  }

  void _notify() {
    June.getState(juneRefresher).setState();
  }

  /// A callback which provides the [Dao]p with the ability to notify
  /// the [JuneState] returned by [juneRefresher].
  /// The [Dao] notifies the [juneRefresher] when ever the table
  /// is changed via one of the standard CRUD operations exposed
  /// by the Dao.
  JuneStateCreator get juneRefresher;

  T fromMap(Map<String, dynamic> map);

  String get tableName;
}
