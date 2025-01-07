import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/system.dart';
import 'dao.dart';

class DaoSystem extends Dao<System> {
  Future<void> createTable(Database db, int version) async {}

  @override
  System fromMap(Map<String, dynamic> map) => System.fromMap(map);

  Future<System> get() async => (await getById(1))!;

  @override
  String get tableName => 'system';
  @override
  JuneStateCreator get juneRefresher => SystemState.new;

  Future<Money> getHourlyRate() async {
    final system = await get();

    return system.defaultHourlyRate ?? Money.parse('100', isoCode: 'AUD');
  }
}

/// Used to notify the UI that the time entry has changed.
class SystemState extends JuneState {
  SystemState();
}
