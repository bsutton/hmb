import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_invoice.dart';
import 'package:hmb/dao/dao_quickbooks.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/quickbooks_settings.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../database/management/db_utility_test_helper.dart';
import 'invoice/utility.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);
  test(
    'migration defaults to disconnected sandbox and settings roundtrip',
    () async {
      final dao = DaoQuickBooks();
      expect((await dao.settings()).sandbox, isTrue);
      expect((await dao.settings()).clientId, isEmpty);
      await dao.saveSettings(
        const QuickBooksSettings(
          clientId: 'test',
          redirectUri: 'http://localhost/callback',
          itemId: '7',
        ),
      );
      expect((await dao.settings()).itemId, '7');
    },
  );
  test(
    'export snapshot is durable, idempotent and prevents destructive delete',
    () async {
      final contact = await createContact('Test', 'Customer');
      final job = await createJob(
        DateTime.now(),
        BillingType.timeAndMaterial,
        contact: contact,
        hourlyRate: MoneyEx.dollars(50),
      );
      final invoice = Invoice.forInsert(
        jobId: job.id,
        dueDate: LocalDate(2026, 10, 3),
        totalAmount: MoneyEx.dollars(110),
        billingContactId: contact.id,
      );
      await DaoInvoice().insert(invoice);
      final dao = DaoQuickBooks();
      final first = await dao.prepareExport(
        invoiceId: invoice.id,
        realmId: '42',
        sandbox: true,
        payload: '{}',
      );
      final retry = await dao.prepareExport(
        invoiceId: invoice.id,
        realmId: '42',
        sandbox: true,
        payload: '{}',
      );
      expect(retry['request_id'], first['request_id']);
      await expectLater(
        dao.prepareExport(
          invoiceId: invoice.id,
          realmId: '43',
          sandbox: true,
          payload: '{}',
        ),
        throwsFormatException,
      );
      await expectLater(
        dao.prepareExport(
          invoiceId: invoice.id,
          realmId: '42',
          sandbox: true,
          payload: '{"changed":true}',
        ),
        throwsFormatException,
      );
      await dao.completeExport(invoice.id, {
        'Id': '99',
        'DocNumber': 'QB-1',
        'TotalAmt': 110,
      });
      expect((await dao.exportFor(invoice.id))!['external_id'], '99');
      await expectLater(DaoInvoice().delete(invoice.id), throwsStateError);
      expect(await DaoInvoice().getById(invoice.id), isNotNull);
    },
  );
}
