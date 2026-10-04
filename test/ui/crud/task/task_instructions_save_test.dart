@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/task/list_task_screen.dart';
import 'package:hmb/ui/crud/task/task_instructions_screen.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test('saves non-empty task drafts to the job awaiting approval', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      status: JobStatus.inProgress,
    );

    final count = await saveTaskInstructionDrafts(
      jobId: job.id,
      drafts: const [
        TaskInstructionDraft(
          name: '  Replace tap washer  ',
          description: '  Repair the kitchen tap.  ',
        ),
        TaskInstructionDraft(name: '  ', description: 'Ignore this draft.'),
      ],
    );

    final tasks = await DaoTask().getTasksByJob(job.id);
    expect(count, 1);
    expect(tasks, hasLength(1));
    expect(tasks.single.name, 'Replace tap washer');
    expect(tasks.single.description, 'Repair the kitchen tap.');
    expect(tasks.single.status, TaskStatus.awaitingApproval);
  });
}
