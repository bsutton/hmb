import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/contact.dart';
import '../entity/supplier.dart';
import 'dao.dart';
import 'dao_contact.dart';

class DaoContactSupplier extends Dao<Contact> {
  Future<void> createTable(Database db, int version) async {}

  @override
  Contact fromMap(Map<String, dynamic> map) => Contact.fromMap(map);

  @override
  String get tableName => 'supplier_contact';

  Future<void> deleteJoin(Supplier supplier, Contact contact,
      [Transaction? transaction]) async {
    await withinTransaction(transaction).delete(
      tableName,
      where: 'supplier_id = ? and contact_id = ?',
      whereArgs: [supplier.id, contact.id],
    );
    await DaoContact().delete(contact.id);
  }

  Future<void> insertJoin(Contact contact, Supplier supplier,
      [Transaction? transaction]) async {
    await withinTransaction(transaction).insert(
      tableName,
      {'supplier_id': supplier.id, 'contact_id': contact.id},
    );
  }

  Future<void> setAsPrimary(Contact contact, Supplier supplier,
      [Transaction? transaction]) async {
    await withinTransaction(transaction).update(
      tableName,
      {'primary': 1},
      where: 'supplier_id = ? and contact_id = ?',
      whereArgs: [supplier.id, contact.id],
    );
  }

  @override
  JuneStateCreator get juneRefresher => ContactSupplierState.new;
}

/// Used to notify the UI that the time entry has changed.
class ContactSupplierState extends JuneState {
  ContactSupplierState();
}
