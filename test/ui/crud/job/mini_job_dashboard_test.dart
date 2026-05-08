@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/job/mini_job_dashboard.dart';

void main() {
  test('task dashlet value shows open and completed counts', () {
    final value = taskDashletValue([
      _task(TaskStatus.awaitingApproval),
      _task(TaskStatus.inProgress),
      _task(TaskStatus.completed),
      _task(TaskStatus.onHold),
      _task(TaskStatus.cancelled),
    ]);

    expect(value.value, '2/1');
  });
}

Task _task(TaskStatus status) => Task.forInsert(
  jobId: 1,
  name: status.name,
  description: '',
  status: status,
);
