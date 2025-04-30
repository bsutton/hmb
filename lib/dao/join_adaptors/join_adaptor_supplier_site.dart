// ignore_for_file: library_private_types_in_public_api

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
  Future<List<Site>> getByParent(Supplier? supplier)  =>
      DaoSite().getBySupplier(supplier);

  @override
  Future<void> insertForParent(Site contact, Supplier supplier) async {
    await DaoSite().insertForSupplier(contact, supplier);
  }

  @override
  Future<void> setAsPrimary(Site child, Supplier supplier) async {
    await DaoSiteSupplier().setAsPrimary(child, supplier);
  }
}
