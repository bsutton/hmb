import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/contact.dart';
import '../entity/customer.dart';
import '../entity/job.dart';
import '../entity/supplier.dart';
import 'dao.dart';
import 'dao_contact_customer.dart';
import 'dao_contact_job.dart';
import 'dao_contact_supplier.dart';

class DaoContact extends Dao<Contact> {
  Future<void> createTable(Database db, int version) async {}

  @override
  Contact fromMap(Map<String, dynamic> map) => Contact.fromMap(map);

  @override
  String get tableName => 'contact';

  /// returns the primary contact for the customer
  Future<Contact?> getPrimaryForCustomer(Customer customer) async {
    final db = getDb();
    final data = await db.rawQuery('''
select co.* 
from contact co
join customer_contact cc
  on co.id = cc.contact_id
join customer cu
  on cc.customer_id = cu.id
where cu.id =? 
and cc.`primary` = 1''', [customer.id]);

    if (data.isEmpty) {
      return (await DaoContact().getByCustomer(customer)).firstOrNull;
    }
    return fromMap(data.first);
  }

  /// returns the primary contact for the customer
  Future<Contact?> getPrimaryForSupplier(Supplier supplier) async {
    final db = getDb();
    final data = await db.rawQuery('''
select co.* 
from contact co
join supplier_contact sc
  on co.id = sc.contact_id
join supplier su
  on sc.supplier_id = su.id
where su.id =? 
and sc.`primary` = 1''', [supplier.id]);

    if (data.isEmpty) {
      return (await DaoContact().getBySupplier(supplier)).firstOrNull;
    }
    return fromMap(data.first);
  }

  Future<List<Contact>> getByCustomer(Customer? customer) async {
    final db = getDb();

    if (customer == null) {
      return [];
    }
    final data = await db.rawQuery('''
select co.* 
from contact co
join customer_contact cc
  on co.id = cc.contact_id
join customer cu
  on cc.customer_id = cu.id
where cu.id =? 
''', [customer.id]);

    return toList(data);
  }

  /// returns the primary contact for the supplier

  Future<List<Contact>> getBySupplier(Supplier? supplier) async {
    final db = getDb();

    if (supplier == null) {
      return [];
    }
    final data = await db.rawQuery('''
select co.* 
from contact co
join supplier_contact cc
  on co.id = cc.contact_id
join supplier cu
  on cc.supplier_id = cu.id
where cu.id =? 
''', [supplier.id]);

    return toList(data);
  }

  Future<List<Contact>> getByJob(Job? job) async {
    final db = getDb();

    if (job == null) {
      return [];
    }
    final data = await db.rawQuery('''
select co.* 
from contact co
join job_contact cc
  on co.id = cc.contact_id
join job cu
  on cc.job_id = cu.id
where cu.id =? 
''', [job.id]);

    return toList(data);
  }

  Future<void> deleteFromCustomer(Contact contact, Customer customer) async {
    await DaoContactCustomer().deleteJoin(customer, contact);
    await delete(contact.id);
  }

  Future<void> insertForCustomer(Contact contact, Customer customer) async {
    await insert(contact);
    await DaoContactCustomer().insertJoin(contact, customer);
  }

  Future<void> deleteFromSupplier(Contact contact, Supplier supplier) async {
    await DaoContactSupplier().deleteJoin(supplier, contact);
    await delete(contact.id);
  }

  Future<void> insertForSupplier(Contact contact, Supplier supplier) async {
    await insert(contact);
    await DaoContactSupplier().insertJoin(contact, supplier);
  }

  Future<void> deleteFromJob(Contact contact, Job job) async {
    await DaoContactJob().deleteJoin(job, contact);
    await delete(contact.id);
  }

  Future<void> insertForJob(Contact contact, Job job) async {
    await insert(contact);
    await DaoContactJob().insertJoin(contact, job);
  }

  @override
  JuneStateCreator get juneRefresher => ContactState.new;
}

/// Used to notify the UI that the time entry has changed.
class ContactState extends JuneState {
  ContactState();
}
