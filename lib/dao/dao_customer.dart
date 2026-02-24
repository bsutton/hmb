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

import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:strings/strings.dart';

import '../entity/customer.dart';
import '../util/dart/exceptions.dart';
import 'dao.dart';
import 'dao_system.dart';

class DaoCustomer extends Dao<Customer> {
  static const tableName = 'customer';
  DaoCustomer() : super(tableName);
  Future<void> createTable(Database db, int version) async {}

  @override
  Customer fromMap(Map<String, dynamic> map) => Customer.fromMap(map);

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    final db = withinTransaction(transaction);

    final dependencyRows = await db.rawQuery(
      '''
SELECT
  (SELECT COUNT(*) FROM job j WHERE j.customer_id = ?) AS job_count,
  (
    SELECT COUNT(*)
    FROM quote q
    JOIN job j ON j.id = q.job_id
    WHERE j.customer_id = ?
  ) AS quote_count,
  (
    SELECT COUNT(*)
    FROM invoice i
    JOIN job j ON j.id = i.job_id
    WHERE j.customer_id = ?
  ) AS invoice_count
''',
      [id, id, id],
    );

    final counts = dependencyRows.first;
    final jobCount = counts['job_count'] as int? ?? 0;
    final quoteCount = counts['quote_count'] as int? ?? 0;
    final invoiceCount = counts['invoice_count'] as int? ?? 0;

    if (jobCount > 0 || quoteCount > 0 || invoiceCount > 0) {
      throw HMBException(
        'Customer cannot be deleted while related records exist '
        '(jobs: $jobCount, quotes: $quoteCount, invoices: $invoiceCount).',
      );
    }

    await db.delete(
      'customer_contact',
      where: 'customer_id = ?',
      whereArgs: [id],
    );
    await db.delete('customer_site', where: 'customer_id = ?', whereArgs: [id]);

    return super.delete(id, transaction);
  }

  /// Get the customer passed on the passed job.
  Future<Customer?> getByJob(int? jobId) async {
    final db = withoutTransaction();

    if (jobId == null) {
      return null;
    }
    final data = await db.rawQuery(
      '''
select c.* 
from job j
join customer c
  on c.id = j.customer_id
where j.id =? 
''',
      [jobId],
    );

    return toList(data).first;
  }

  Future<List<Customer>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    if (Strings.isBlank(filter)) {
      return getAll(orderByClause: 'modifiedDate desc');
    }
    return toList(
      await db.rawQuery(
        '''
select c.* 
from customer c
where c.name like ?
order by c.modifiedDate desc
''',
        ['''%$filter%'''],
      ),
    );
  }

  Future<List<Customer>> getByName(String name) async {
    final db = withoutTransaction();
    if (Strings.isBlank(name)) {
      return [];
    }
    final data = await db.rawQuery(
      '''
select *
from customer
where lower(name) = lower(?)
''',
      [name.trim()],
    );
    return toList(data);
  }

  Future<Customer?> getByQuote(int quoteId) async {
    final db = withoutTransaction();
    final data = await db.rawQuery(
      '''
      SELECT c.* 
      FROM customer c
      JOIN job j ON c.id = j.customer_id
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

  Future<Money> getHourlyRate(int customerId) async {
    final customer = await getById(customerId);

    Money hourlyRate;
    if (customer?.hourlyRate == null) {
      hourlyRate =
          (await DaoSystem().get()).defaultHourlyRate ??
          Money.fromInt(0, isoCode: 'AUD');
    } else {
      hourlyRate = customer?.hourlyRate ?? Money.fromInt(0, isoCode: 'AUD');
    }
    return hourlyRate;
  }

  /// Get the customer associated with the given contact ID.
  Future<Customer?> getByContact(int contactId) async {
    final db = withoutTransaction();

    final data = await db.rawQuery(
      '''
      SELECT c.*
      FROM customer c
      LEFT JOIN customer_contact cc ON c.id = cc.customer_id
      WHERE cc.contact_id = ?
      LIMIT 1
    ''',
      [contactId],
    );

    if (data.isEmpty) {
      return null;
    }

    return fromMap(data.first);
  }

  /// Get the customer associated with the given site ID.
  Future<Customer?> getBySite(int siteId) async {
    final db = withoutTransaction();

    final data = await db.rawQuery(
      '''
      SELECT c.*
      FROM customer c
      LEFT JOIN customer_site cs ON c.id = cs.customer_id
      WHERE cs.site_id = ?
      LIMIT 1
    ''',
      [siteId],
    );

    if (data.isEmpty) {
      return null;
    }

    return fromMap(data.first);
  }
}
