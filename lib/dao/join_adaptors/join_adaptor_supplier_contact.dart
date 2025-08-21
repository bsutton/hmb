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


// ignore_for_file: library_private_types_in_public_api

import 'package:sqflite_common/sqlite_api.dart';

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
  Future<List<Contact>> getByParent(Supplier? supplier) =>
      DaoContact().getBySupplier(supplier);

  @override
  Future<void> insertForParent(
    Contact contact,
    Supplier supplier,
    Transaction transaction,
  ) async {
    await DaoContact().insertForSupplier(contact, supplier, transaction);
  }

  @override
  Future<void> setAsPrimary(Contact child, Supplier supplier) async {
    await DaoContactSupplier().setAsPrimary(child, supplier);
  }
}
