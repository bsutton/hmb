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

import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/contact.dart';
import '../entity/customer.dart';
import 'dao.dart';

class DaoContactCustomer extends Dao<Contact> {
  Future<void> createTable(Database db, int version) async {}

  @override
  Contact fromMap(Map<String, dynamic> map) => Contact.fromMap(map);

  @override
  String get tableName => 'customer_contact';

  Future<void> deleteJoin(
    Customer customer,
    Contact contact, [
    Transaction? transaction,
  ]) async {
    await withinTransaction(transaction).delete(
      tableName,
      where: 'customer_id = ? and contact_id = ?',
      whereArgs: [customer.id, contact.id],
    );
  }

  Future<void> insertJoin(
    Contact contact,
    Customer customer, [
    Transaction? transaction,
  ]) async {
    await withinTransaction(
      transaction,
    ).insert(tableName, {'customer_id': customer.id, 'contact_id': contact.id});
  }

  Future<void> setAsPrimary(
    Contact contact,
    Customer customer, [
    Transaction? transaction,
  ]) async {
    await withinTransaction(transaction).update(
      tableName,
      {'primary': 1},
      where: 'customer_id = ? and contact_id = ?',
      whereArgs: [customer.id, contact.id],
    );
  }

  @override
  JuneStateCreator get juneRefresher => ContactCustomerState.new;
}

/// Used to notify the UI that the time entry has changed.
class ContactCustomerState extends JuneState {
  ContactCustomerState();
}
