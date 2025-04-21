import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';
import 'package:strings/strings.dart';

import '../entity/customer.dart';
import '../entity/job.dart';
import '../entity/site.dart';
import '../entity/supplier.dart';
import 'dao.dart';
import 'dao_site_customer.dart';
import 'dao_site_supplier.dart';

class DaoSite extends Dao<Site> {
  Future<void> createTable(Database db, int version) async {}

  @override
  Site fromMap(Map<String, dynamic> map) => Site.fromMap(map);

  @override
  String get tableName => 'site';

  /// returns the primary site for the customer
  Future<Site?> getPrimaryForCustomer(int? customerId) async {
    if (customerId == null) {
      return null;
    }

    final db = withoutTransaction();
    final data = await db.rawQuery(
      '''
select s.* 
from site s
join customer_site sc
  on s.id = sc.site_id
join customer cu
  on sc.customer_id = cu.id
where cu.id =? 
and sc.`primary` = 1''',
      [customerId],
    );

    if (data.isEmpty) {
      return (await DaoSite().getByCustomer(customerId)).firstOrNull;
    }
    return fromMap(data.first);
  }

  /// returns the primary site for the supplier
  Future<Site?> getPrimaryForSupplier(Supplier? supplier) async {
    if (supplier == null) {
      return null;
    }

    final db = withoutTransaction();
    final data = await db.rawQuery(
      '''
select s.* 
from site s
join supplier_site sc
  on s.id = sc.site_id
join supplier cu
  on sc.supplier_id = cu.id
where cu.id =? 
and sc.`primary` = 1''',
      [supplier.id],
    );

    if (data.isEmpty) {
      return (await DaoSite().getBySupplier(supplier)).firstOrNull;
    }
    return fromMap(data.first);
  }

  Future<List<Site>> getByCustomer(int? customerId) async {
    final db = withoutTransaction();

    if (customerId == null) {
      return [];
    }
    return toList(
      await db.rawQuery(
        '''
select s.* 
from site s
join customer_site sc
  on s.id = sc.site_id
join customer cu
  on sc.customer_id = cu.id
where cu.id =? 
''',
        [customerId],
      ),
    );
  }

  /// search for Sites given a user supplied filter string.
  Future<List<Site>> getByFilter(int? customerId, String? filter) async {
    final db = withoutTransaction();

    if (customerId == null) {
      return [];
    }
    if (Strings.isBlank(filter)) {
      return getByCustomer(customerId);
    }

    final likeArg = '''%$filter%''';
    return toList(
      await db.rawQuery(
        '''
select s.*
from site s
join customer c
  on c.id = s.customer_id
where s.addressLine1 like ?
or s.addressLine2 like ?
or s.suburb like ?
or s.state like ?
or s.postcode like ?
''',
        [likeArg, likeArg, likeArg, likeArg, likeArg],
      ),
    );
  }

  Future<List<Site>> getBySupplier(Supplier? supplier) async {
    final db = withoutTransaction();

    if (supplier == null) {
      return [];
    }
    return toList(
      await db.rawQuery(
        '''
select s.* 
from site s
join supplier_site sc
  on s.id = sc.site_id
join supplier cu
  on sc.supplier_id = cu.id
where cu.id =? 
''',
        [supplier.id],
      ),
    );
  }

  Future<Site?> getByJob(Job? job) async {
    final db = withoutTransaction();

    if (job == null) {
      return null;
    }
    final data = await db.rawQuery(
      '''
select si.* 
from site si
join job jo
  on jo.site_id = si.id
where jo.id =? 
''',
      [job.id],
    );

    final list = toList(data);

    if (list.isEmpty) {
      return null;
    }
    return list.first;
  }

  Future<void> deleteFromCustomer(Site site, Customer customer) async {
    await DaoSiteCustomer().deleteJoin(customer, site);
    await delete(site.id);
  }

  Future<void> insertForCustomer(Site site, Customer customer) async {
    await insert(site);
    await DaoSiteCustomer().insertJoin(site, customer);
  }

  Future<void> deleteFromSupplier(Site site, Supplier supplier) async {
    await DaoSiteSupplier().deleteJoin(supplier, site);
    await delete(site.id);
  }

  Future<void> insertForSupplier(Site site, Supplier supplier) async {
    await insert(site);
    await DaoSiteSupplier().insertJoin(site, supplier);
  }

  Future<void> deleteFromJob(Site site, Job job) async {
    await delete(site.id);
  }

  Future<void> insertForJob(Site site, Job job) async {
    await insert(site);
  }

  @override
  JuneStateCreator get juneRefresher => SiteState.new;
}

/// Used to notify the UI that the time entry has changed.
class SiteState extends JuneState {
  SiteState();
}
