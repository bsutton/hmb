import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/api/xero/xero_invoice_payment_sync_service.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/log.dart';

import '../../database/management/db_utility_test_helper.dart';

void main() {
  setUpAll(() {
    Log.configure('.');
  });

  setUp(() async {
    await setupTestDb();
    final system = await DaoSystem().get();
    await DaoSystem().update(
      system.copyWith(enableXeroIntegration: true, xeroClientId: 'client-id'),
    );
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('does not attempt Xero login when no invoices need syncing', () async {
    var loginAttempts = 0;
    final service = XeroInvoicePaymentSyncService(
      daoInvoice: _EmptyPendingInvoiceDao(),
      login: ({allowInteractive = true}) async {
        loginAttempts += 1;
        return true;
      },
    );

    final updated = await service.sync(force: true);

    expect(updated, 0);
    expect(loginAttempts, 0);
  });
}

class _EmptyPendingInvoiceDao extends DaoInvoice {
  @override
  Future<List<Invoice>> getUploadedUnpaid() async => [];
}
