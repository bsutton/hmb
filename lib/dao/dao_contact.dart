import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';
import 'package:strings/strings.dart';

import '../entity/contact.dart';
import '../entity/customer.dart';
import '../entity/job.dart';
import '../entity/supplier.dart';
import 'dao.dart';
import 'dao_contact_customer.dart';
import 'dao_contact_supplier.dart';
import 'dao_job.dart';

class DaoContact extends Dao<Contact> {
  Future<void> createTable(Database db, int version) async {}

  @override
  Contact fromMap(Map<String, dynamic> map) => Contact.fromMap(map);

  @override
  String get tableName => 'contact';

  ///
  /// returns the primary contact for the customer
  ///
  Future<Contact?> getPrimaryForCustomer(int? customerId) async {
    final db = withoutTransaction();

    if (customerId == null) {
      return null;
    }
    final data = await db.rawQuery(
      '''
select co.* 
from contact co
join customer_contact cc
  on co.id = cc.contact_id
join customer cu
  on cc.customer_id = cu.id
where cu.id =? 
and cc.`primary` = 1''',
      [customerId],
    );

    if (data.isEmpty) {
      return (await DaoContact().getByCustomer(customerId)).firstOrNull;
    }
    return fromMap(data.first);
  }

  ///
  /// returns the primary contact for the job
  ///
  Future<Contact?> getPrimaryForJob(int? jobId) async {
    final db = withoutTransaction();

    if (jobId == null) {
      return null;
    }
    final data = await db.rawQuery(
      '''
select co.* 
from contact co
join job jo
  on co.id = jo.contact_id
where jo.id =? 
''',
      [jobId],
    );

    if (data.isEmpty) {
      final job = await DaoJob().getById(jobId);
      return DaoContact().getPrimaryForCustomer(job?.customerId);
    }
    return fromMap(data.first);
  }

  Future<Contact?> getPrimaryForQuote(int quoteId) async {
    final db = withoutTransaction();
    final data = await db.rawQuery(
      '''
      SELECT c.*
      FROM contact c
      JOIN job j ON c.id = j.contact_id
      JOIN quote q ON j.id = q.job_id
      WHERE q.id = ?
    ''',
      [quoteId],
    );

    if (data.isEmpty) {
      return null;
    }
    return fromMap(data.first);
  }

  ///
  /// returns the primary contact for the customer
  ///
  Future<Contact?> getPrimaryForSupplier(Supplier supplier) async {
    final db = withoutTransaction();
    final data = await db.rawQuery(
      '''
select co.* 
from contact co
join supplier_contact sc
  on co.id = sc.contact_id
join supplier su
  on sc.supplier_id = su.id
where su.id =? 
and sc.`primary` = 1''',
      [supplier.id],
    );

    if (data.isEmpty) {
      return (await DaoContact().getBySupplier(supplier)).firstOrNull;
    }
    return fromMap(data.first);
  }

  Future<List<Contact>> getByCustomer(int? customerId) async {
    final db = withoutTransaction();

    if (customerId == null) {
      return [];
    }
    return toList(
      await db.rawQuery(
        '''
select co.* 
from contact co
join customer_contact cc
  on co.id = cc.contact_id
join customer cu
  on cc.customer_id = cu.id
where cu.id =? 
''',
        [customerId],
      ),
    );
  }

  /// returns the primary contact for the supplier

  Future<List<Contact>> getBySupplier(Supplier? supplier) async {
    final db = withoutTransaction();

    if (supplier == null) {
      return [];
    }
    return toList(
      await db.rawQuery(
        '''
select co.* 
from contact co
join supplier_contact cc
  on co.id = cc.contact_id
join supplier cu
  on cc.supplier_id = cu.id
where cu.id =? 
''',
        [supplier.id],
      ),
    );
  }

  Future<List<Contact>> getByJob(int? jobId) async {
    final db = withoutTransaction();

    if (jobId == null) {
      return [];
    }
    return toList(
      await db.rawQuery(
        '''
select co.* 
from contact co
join job jo
  on co.id = jo.contact_id
where jo.id =? 
''',
        [jobId],
      ),
    );
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
    await delete(contact.id);
  }

  Future<void> insertForJob(Contact contact, Job job) async {
    await insert(contact);
  }

  @override
  JuneStateCreator get juneRefresher => ContactState.new;

  Future<List<Contact>> getByFilter(Customer customer, String? filter) async {
    final db = withoutTransaction();

    if (Strings.isBlank(filter)) {
      return getAll(orderByClause: 'modifiedDate desc');
    }
    return toList(
      await db.rawQuery(
        '''
select c.* 
form contact c
join customer_contact cc
  on c.id = cc.contact_id
join customer cu
  on cc.customer_id = cu.id
where c.name like ?
order by c.modifiedDate desc
''',
        ['''%$filter%'''],
      ),
    );
  }

  /// Returns the customer's billing contact if set; otherwise the contact
  /// with the lowest ID among that customer's contacts.
  Future<Contact?> getBillingContactByCustomer(Customer customer) async {
    // Load a plain sqlite db instance (no active transaction)
    final db = withoutTransaction();

    // Use -1 as a dummy so no contact.id == -1, forcing fallback if null
    final billingId = customer.billingContactId ?? -1;

    final rows = await db.rawQuery(
      '''
      SELECT c.* 
        FROM contact AS c
        JOIN $tableName AS cc 
          ON cc.contact_id = c.id
       WHERE cc.customer_id = ?
       ORDER BY (c.id = ?) DESC, c.id ASC
       LIMIT 1
      ''',
      <Object?>[customer.id, billingId],
    );

    if (rows.isEmpty) {
      return null;
    }

    return Contact.fromMap(rows.first);
  }
}

/// Used to notify the UI that the time entry has changed.
class ContactState extends JuneState {
  ContactState();
}
