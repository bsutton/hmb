import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/database/versions/post_upgrade/post_upgrade_134.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../../ui/ui_test_helpers.dart';
import '../../util/settings_test_helper.dart';
import 'db_utility_test_helper.dart';

void main() {
  setUpAll(prepareSettingsTest);
  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });
  tearDown(tearDownTestDb);

  test('startup rich text migration completes with existing jobs', () async {
    await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      bookingFee: MoneyEx.zero,
    );
    final system = await DaoSystem().getForUpdate();
    system.richTextRemoved = RichTextRemoved.notYet;
    await DaoSystem().updateConfiguration(system);
    await postv134Upgrade(
      DatabaseHelper.instance.database,
    ).timeout(const Duration(seconds: 5));
    expect((await DaoSystem().get()).richTextRemoved, RichTextRemoved.quote);
  });
}
