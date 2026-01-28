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

import '../../entity/site.dart';
import '../../entity/supplier.dart';
import '../dao_site.dart';
import '../dao_site_supplier.dart';
import 'dao_join_adaptor.dart';

class JoinAdaptorSupplierSite implements DaoJoinAdaptor<Site, Supplier> {
  @override
  Future<void> deleteFromParent(Site site, Supplier supplier) async {
    await DaoSite().deleteFromSupplier(site, supplier);
  }

  @override
  Future<List<Site>> getByParent(Supplier? supplier) =>
      DaoSite().getBySupplier(supplier);

  @override
  Future<void> insertForParent(
    Site contact,
    Supplier supplier,
    Transaction transaction,
  ) async {
    await DaoSite().insertForSupplier(contact, supplier, transaction);
  }

  @override
  Future<void> setAsPrimary(Site child, Supplier supplier) async {
    await DaoSiteSupplier().setAsPrimary(child, supplier);
  }
}
