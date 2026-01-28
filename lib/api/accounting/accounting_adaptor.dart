import 'package:meta/meta.dart';

import '../../dao/dao_system.dart';
import '../../entity/invoice.dart';

abstract class AccountingAdaptor {
  static late final AccountingAdaptor? _instance;
  @protected
  AccountingAdaptor();

  Future<void> markSent(Invoice invoice);

  Future<void> markApproved(Invoice invoice);

  Future<void> uploadInvoice(Invoice invoice);

  Future<void> login();

  // ignore: avoid_setters_without_getters
  static set instance(AccountingAdaptor instance) => _instance = instance;

  static Future<bool> get isEnabled async =>
      (await DaoSystem().get()).isExternalAccountingEnabled();

  static AccountingAdaptor get() => _instance!;
}
