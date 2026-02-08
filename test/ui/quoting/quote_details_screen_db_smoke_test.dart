import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_job.dart';

import '../../database/management/db_utility_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pumpWidget with test db', (tester) async {
    addTearDown(() async {
      await tearDownTestDb();
    });

    /// test that dao access works within a test unit.
    await tester.runAsync(() async {
      await setupTestDb();
      const jobId = 1;
      await DaoJob().getById(jobId);
    });

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
  });
}
