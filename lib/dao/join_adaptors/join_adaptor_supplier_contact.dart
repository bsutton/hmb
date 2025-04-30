// ignore_for_file: library_private_types_in_public_api

import '../../entity/contact.dart';
import '../../entity/supplier.dart';
import '../dao_contact.dart';
import '../dao_contact_supplier.dart';
import 'dao_join_adaptor.dart';

class JoinAdaptorSupplierContact implements DaoJoinAdaptor<Contact, Supplier> {
  @override
  Future<void> deleteFromParent(Contact contact, Supplier supplier) async {
    await DaoContactSupplier().deleteJoin(supplier, contact);
  }

  @override
  Future<List<Contact>> getByParent(Supplier? supplier)  =>
      DaoContact().getBySupplier(supplier);

  @override
  Future<void> insertForParent(Contact contact, Supplier supplier) async {
    await DaoContact().insertForSupplier(contact, supplier);
  }

  @override
  Future<void> setAsPrimary(Contact child, Supplier supplier) async {
    await DaoContactSupplier().setAsPrimary(child, supplier);
  }
}
