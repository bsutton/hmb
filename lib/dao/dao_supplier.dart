import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/supplier.dart';
import 'dao.dart';

class DaoSupplier extends Dao<Supplier> {
  Future<void> createTable(Database db, int version) async {}

  @override
  Supplier fromMap(Map<String, dynamic> map) => Supplier.fromMap(map);

  @override
  String get tableName => 'supplier';
  @override
  JuneStateCreator get juneRefresher => SupplierState.new;
}

/// Used to notify the UI that the time entry has changed.
class SupplierState extends JuneState {
  SupplierState();
}
