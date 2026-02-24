import 'package:hmb/api/chat_gpt/job_assist_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeJobAssistTasks', () {
    test('trims and removes empty values', () {
      final tasks = normalizeJobAssistTasks(['  Clean gutters  ', '', '   ']);
      expect(tasks, ['Clean gutters']);
    });

    test('deduplicates case-insensitively preserving first', () {
      final tasks = normalizeJobAssistTasks([
        'Clean gutters',
        'clean gutters',
        'Fix gate latch',
      ]);
      expect(tasks, ['Clean gutters', 'Fix gate latch']);
    });

    test('caps task count to maxTasks', () {
      final tasks = normalizeJobAssistTasks([
        'Task 1',
        'Task 2',
        'Task 3',
        'Task 4',
      ], maxTasks: 2);
      expect(tasks, ['Task 1', 'Task 2']);
    });
  });
}
