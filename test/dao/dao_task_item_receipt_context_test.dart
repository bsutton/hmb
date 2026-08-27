import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';
import 'invoice/utility.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test(
    'receipt match context searches item, task, job, customer and contact',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Kitchen renovation',
      );
      final customer = (await DaoCustomer().getById(
        job.customerId,
      ))!.copyWith(name: 'Harbour Apartments');
      await DaoCustomer().update(customer);
      final contact = (await DaoContact().getById(
        job.contactId,
      ))!.copyWith(firstName: 'Morgan', surname: 'Manager');
      await DaoContact().update(contact);
      final task = await createTask(job, 'Install splashback');
      final item = await insertMaterialItem(
        task,
        itemType: TaskItemType.materialsBuy,
        description: 'Ceramic tiles',
        actualQuantity: Fixed.one,
        actualUnitCost: Money.fromInt(1000, isoCode: 'AUD'),
      );

      final context = (await DaoTaskItem().getReceiptMatchContexts([
        item.id,
      ]))[item.id]!;

      for (final search in [
        'ceramic',
        'splashback',
        'kitchen',
        'harbour',
        'morgan',
        '${job.id}',
      ]) {
        expect(context.matches(search, item.description), isTrue);
      }
      expect(context.display, contains('Task: Install splashback'));
      expect(context.matches('unrelated', item.description), isFalse);
    },
  );
}
