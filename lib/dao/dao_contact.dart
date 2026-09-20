// ignore_for_file: async_return_with_no_await

/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:sqflite_common/sqlite_api.dart';
import 'package:strings/strings.dart';

import '../entity/contact.dart';
import '../entity/customer.dart';
import '../entity/job.dart';
import '../entity/supplier.dart';
import '../util/dart/exceptions.dart';
import 'dao.dart';
import 'dao_contact_customer.dart';
import 'dao_contact_role.dart';
import 'dao_contact_supplier.dart';
import 'dao_job.dart';
import 'dao_reference_guard.dart';
import 'job_billing_contact.dart';

class DaoContact extends Dao<Contact> {
  static const tableName = 'contact';
  DaoContact() : super(tableName);
  Future<void> createTable(Database db, int version) async {}

  Future<void> _canonicalRole(Contact contact, Transaction txn) async {
    // Legacy import callers may still supply a description. Resolve it to a
    // real role; the database never receives an independent free-form value.
    if (contact.defaultRoleId == null &&
        contact.roleDescription.trim().isNotEmpty) {
      final roles = await DaoContactRole().getAll(txn);
      final name = contact.roleDescription.trim();
      final matched = roles
          .where((role) => role.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      contact.defaultRoleId =
          matched?.id ?? await DaoContactRole().create(name, txn);
    }
    final role = await DaoContactRole().getById(contact.defaultRoleId, txn);
    if (contact.defaultRoleId != null && role == null) {
      throw HMBException('Select an existing contact role.');
    }
    contact.roleDescription = role?.name ?? '';
  }

  @override
  Future<int> insert(Contact entity, [Transaction? transaction]) async {
    if (transaction == null) {
      return db.transaction((txn) => insert(entity, txn));
    }
    await _canonicalRole(entity, transaction);
    return super.insert(entity, transaction);
  }

  @override
  Future<int> update(Contact entity, [Transaction? transaction]) async {
    if (transaction == null) {
      return db.transaction((txn) => update(entity, txn));
    }
    await _canonicalRole(entity, transaction);
    return super.update(entity, transaction);
  }

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    await DaoReferenceGuard.ensureNotReferenced(
      db: withinTransaction(transaction),
      entityName: 'Contact',
      id: id,
      references: const [
        DaoReference('job_party', 'contact_id', 'job parties'),
        DaoReference(
          'job',
          'legacy_billing_contact_id',
          'preserved billing contacts',
        ),
        DaoReference('job', 'contact_id', 'jobs'),
        DaoReference('job', 'billing_contact_id', 'job billing contacts'),
        DaoReference('job', 'referrer_contact_id', 'job referrers'),
        DaoReference('job', 'tenant_contact_id', 'job tenants'),
        DaoReference('customer', 'billing_contact_id', 'customers'),
        DaoReference('customer_contact', 'contact_id', 'customers'),
        DaoReference('supplier_contact', 'contact_id', 'suppliers'),
        DaoReference('supplier_assignment', 'contact_id', 'assignments'),
        DaoReference('invoice', 'billing_contact_id', 'invoices'),
        DaoReference('milestone', 'billing_contact_id', 'milestones'),
        DaoReference(
          'debtor_transaction',
          'debtor_contact_id',
          'debtor transactions',
        ),
        DaoReference('debtor_payment', 'contact_id', 'debtor payments'),
        DaoReference('credit_note', 'contact_id', 'credit notes'),
        DaoReference('mailing_recipient', 'contact_id', 'mailings'),
      ],
    );
    return super.delete(id, transaction);
  }

  @override
  Contact fromMap(Map<String, dynamic> map) => Contact.fromMap(map);

  ///
  /// returns the primary contact for the customer
  ///
  Future<Contact?> getPrimaryForCustomer(
    int? customerId, [
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);

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
      return (await getByCustomer(customerId, transaction)).firstOrNull;
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

  Future<List<Contact>> getByCustomer(
    int? customerId, [
    Transaction? transaction,
  ]) async {
    final db = withinTransaction(transaction);

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

union

select co.* 
from contact co
join job jo
  on co.id = jo.billing_contact_id
where jo.id = ?

union

select co.*
from contact co
join job jo
  on co.id = jo.referrer_contact_id
where jo.id = ?
''',
        [jobId, jobId, jobId],
      ),
    );
  }

  Future<List<Contact>> getByEmail(String email) async {
    final db = withoutTransaction();
    if (Strings.isBlank(email)) {
      return [];
    }
    final data = await db.rawQuery(
      '''
select *
from contact
where lower(emailAddress) = lower(?)
''',
      [email.trim()],
    );
    return toList(data);
  }

  Future<List<Contact>> getByMobile(String mobile) async {
    final db = withoutTransaction();
    if (Strings.isBlank(mobile)) {
      return [];
    }
    final data = await db.rawQuery(
      '''
select *
from contact
where mobileNumber = ?
''',
      [mobile.trim()],
    );
    return toList(data);
  }

  Future<void> deleteFromCustomer(Contact contact, Customer customer) async {
    await DaoContactCustomer().deleteJoin(customer, contact);
    await delete(contact.id);
  }

  Future<void> insertForCustomer(
    Contact contact,
    Customer customer,
    Transaction transaction,
  ) async {
    await insert(contact, transaction);
    await DaoContactCustomer().insertJoin(contact, customer, transaction);
  }

  Future<void> deleteFromSupplier(Contact contact, Supplier supplier) async {
    await DaoContactSupplier().deleteJoin(supplier, contact);
    await delete(contact.id);
  }

  Future<void> insertForSupplier(
    Contact contact,
    Supplier supplier,
    Transaction transaction,
  ) async {
    await insert(contact, transaction);
    await DaoContactSupplier().insertJoin(contact, supplier, transaction);
  }

  Future<void> deleteFromJob(Contact contact, Job job) async {
    await delete(contact.id);
  }

  Future<void> insertForJob(Contact contact, Job job) async {
    await insert(contact);
  }

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

  /// Resolve the visible billing default without changing the Bill To customer.
  Future<Contact?> getBillingContactByJob(Job job) async =>
      (await resolveJobBillingContact(job)).contact;
}
