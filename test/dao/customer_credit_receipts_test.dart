import 'package:hmb/dao/customer_credit_receipts.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test(
    'receipts include customer overpayments and prepayments with balances',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
      );
      final other = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
      );
      for (final kind in ['overpayment', 'prepayment', 'credit_note']) {
        await testDb!.insert('xero_customer_credit', {
          'tenant_id': 'tenant',
          'external_id': kind,
          'customer_id': job.customerId,
          'credit_date': '2026-10-01',
          'amount': 65824,
          'remaining_credit': 35824,
          'credit_kind': kind,
          'reference': 'Duplicate receipt',
        });
        for (final event in ['allocation', 'refund']) {
          await testDb!.insert('xero_customer_credit_event', {
            'tenant_id': 'tenant',
            'credit_id': kind,
            'event_id': event,
            'kind': event,
            'event_date': '2026-10-02',
            'amount': event == 'allocation' ? 20000 : 10000,
          });
        }
      }
      final rows = await loadCustomerCreditReceipts(
        startInclusive: DateTime(2026, 10),
        endExclusive: DateTime(2026, 11),
        customerId: job.customerId,
      );
      expect(
        rows.map((row) => row.kind),
        containsAll(['overpayment', 'prepayment']),
      );
      expect(rows, hasLength(2));
      expect(rows.first.amount, MoneyEx.fromInt(65824));
      expect(rows.first.allocated, MoneyEx.fromInt(20000));
      expect(rows.first.refunded, MoneyEx.fromInt(10000));
      expect(rows.first.remaining, MoneyEx.fromInt(35824));
      expect(
        await loadCustomerCreditReceipts(
          startInclusive: DateTime(2026, 10),
          endExclusive: DateTime(2026, 11),
          customerId: other.customerId,
        ),
        isEmpty,
      );
      expect(
        await loadCustomerCreditReceipts(
          startInclusive: DateTime(2026, 11),
          endExclusive: DateTime(2026, 12),
        ),
        isEmpty,
      );
      expect(
        await loadCustomerCreditReceipts(
          startInclusive: DateTime(2026, 10),
          endExclusive: DateTime(2026, 11),
          search: 'no matching reference',
        ),
        isEmpty,
      );
      await testDb!.update('xero_customer_credit', {'remaining_credit': 0});
      expect(
        await loadCustomerCreditReceipts(
          startInclusive: DateTime(2026, 10),
          endExclusive: DateTime(2026, 11),
          includeFullyAllocated: false,
        ),
        isEmpty,
      );
    },
  );
}
