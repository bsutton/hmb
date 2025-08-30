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
import 'dao.dart';
import 'dao_system.dart';

class DaoCustomer extends Dao<Customer> {
  static const tableName = 'customer';
  DaoCustomer() : super(tableName);
  Future<void> createTable(Database db, int version) async {}

  @override
  Customer fromMap(Map<String, dynamic> map) => Customer.fromMap(map);

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
      LEFT JOIN customer_contacts cc ON c.id = cc.customer_id
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
      LEFT JOIN customer_sites cs ON c.id = cs.customer_id
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
