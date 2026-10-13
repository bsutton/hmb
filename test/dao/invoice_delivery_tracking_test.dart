import 'package:hmb/api/accounting/accounting_adaptor.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  final accounting = _Accounting();
  setUpAll(() => AccountingAdaptor.instance = accounting);
  setUp(() async {
    accounting.calls.clear();
    await setupTestDb();
  });
  tearDown(tearDownTestDb);

  for (final uploaded in [false, true]) {
    test('mark sent persists with uploaded=$uploaded', () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Sample delivery',
      );
      final invoice = Invoice.forInsert(
        jobId: job.id,
        dueDate: LocalDate.today(),
        totalAmount: MoneyEx.dollars(100),
        billingContactId: job.contactId,
      );
      if (uploaded) {
        invoice
          ..externalInvoiceId = 'sample-remote'
          ..paymentSource = InvoicePaymentSource.xero;
      }
      await DaoInvoice().insert(invoice);
      await DaoInvoice().markSent(invoice);
      expect((await DaoInvoice().getById(invoice.id))!.sent, isTrue);
      expect(
        accounting.calls,
        uploaded ? ['login', 'approve', 'sent'] : isEmpty,
      );
    });
  }
}

class _Accounting extends AccountingAdaptor {
  final calls = <String>[];
  @override
  Future<void> login() async => calls.add('login');
  @override
  Future<void> markApproved(Invoice invoice) async => calls.add('approve');
  @override
  Future<void> markSent(Invoice invoice) async => calls.add('sent');
  @override
  Future<void> uploadInvoice(Invoice invoice) async =>
      fail('Email delivery must never upload an invoice');
}
