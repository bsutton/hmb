import 'package:june/june.dart';
import 'package:sqflite/sqflite.dart';

import '../entity/entity.g.dart';
import 'dao.g.dart';

/// Join table DAO: maps suppliers ⇄ contacts
class DaoContactSupplier extends Dao<Contact> {
  @override
  Contact fromMap(Map<String, dynamic> map) => Contact.fromMap(map);

  @override
  String get tableName => 'supplier_contact';

  /// Fetch all Contact rows for a given supplier
  Future<List<Contact>> getBySupplier(int supplierId) async {
    final db = withoutTransaction();
    final rows = await db.rawQuery(
      '''
      SELECT c.*
        FROM supplier_contact sc
        JOIN contact c ON c.id = sc.contact_id
       WHERE sc.supplier_id = ?
      ''',
      [supplierId],
    );
    return toList(rows);
  }

  /// Remove the join and delete the contact itself
  Future<void> deleteJoin(
    Supplier supplier,
    Contact contact, [
    Transaction? transaction,
  ]) async {
    await withinTransaction(transaction).delete(
      tableName,
      where: 'supplier_id = ? AND contact_id = ?',
      whereArgs: [supplier.id, contact.id],
    );
    await DaoContact().delete(contact.id);
  }

  /// Add a supplier-contact mapping
  Future<void> insertJoin(
    Contact contact,
    Supplier supplier, [
    Transaction? transaction,
  ]) async {
    await withinTransaction(
      transaction,
    ).insert(tableName, {'supplier_id': supplier.id, 'contact_id': contact.id});
  }

  /// Mark a particular mapping as primary
  Future<void> setAsPrimary(
    Contact contact,
    Supplier supplier, [
    Transaction? transaction,
  ]) async {
    await withinTransaction(transaction).update(
      tableName,
      {'primary': 1},
      where: 'supplier_id = ? AND contact_id = ?',
      whereArgs: [supplier.id, contact.id],
    );
  }

  @override
  JuneStateCreator get juneRefresher => ContactSupplierState.new;
}

/// UI refresher state for supplier-contact joins
class ContactSupplierState extends JuneState {
  ContactSupplierState();
}
