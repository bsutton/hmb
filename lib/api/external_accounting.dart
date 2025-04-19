import '../dao/dao_system.dart';

class ExternalAccounting {
  Future<bool> isEnabled() async =>
      (await DaoSystem().get()).isExternalAccountingEnabled();
}
