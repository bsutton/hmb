import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/customer.dart';
import '../entity/site.dart';
import 'dao.dart';

class DaoSiteCustomer extends Dao<Site> {
  Future<void> createTable(Database db, int version) async {}

  @override
  Site fromMap(Map<String, dynamic> map) => Site.fromMap(map);

  @override
  String get tableName => 'customer_site';

  Future<void> deleteJoin(Customer customer, Site site,
      [Transaction? transaction]) async {
    await withinTransaction(transaction).delete(
      tableName,
      where: 'customer_id = ? and site_id = ?',
      whereArgs: [customer.id, site.id],
    );
  }

  Future<void> insertJoin(Site site, Customer customer,
      [Transaction? transaction]) async {
    await withinTransaction(transaction).insert(
      tableName,
      {'customer_id': customer.id, 'site_id': site.id},
    );
  }

  Future<void> setAsPrimary(Site site, Customer customer,
      [Transaction? transaction]) async {
    await withinTransaction(transaction).update(
      tableName,
      {'primary': 1},
      where: 'customer_id = ? and site_id = ?',
      whereArgs: [customer.id, site.id],
    );
  }

  @override
  JuneStateCreator get juneRefresher => SiteCustomerState.new;
}

/// Used to notify the UI that the time entry has changed.
class SiteCustomerState extends JuneState {
  SiteCustomerState();
}
