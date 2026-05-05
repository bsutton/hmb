import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('system default profit margin persists', () async {
    final daoSystem = DaoSystem();
    final system = await daoSystem.get();

    system.defaultProfitMargin = Percentage.fromInt(17500, decimalDigits: 3);
    await daoSystem.update(system);

    final updated = await daoSystem.get();
    expect(
      updated.defaultProfitMargin,
      Percentage.fromInt(17500, decimalDigits: 3),
    );
  });

  test('system default profit margin defaults to 20 percent', () async {
    final margin = await DaoSystem().getDefaultProfitMargin();
    expect(margin, Percentage.fromInt(20000, decimalDigits: 3));
  });
}
