import '../entity/task.dart';
import '../entity/task_status.dart';
import 'dao_task.dart';

class TaskEffortRecord {
  final Task task;
  final String jobSummary;
  final String category;
  final Duration duration;
  final int completedEntries;

  const TaskEffortRecord({
    required this.task,
    required this.jobSummary,
    required this.category,
    required this.duration,
    required this.completedEntries,
  });

  double get hours => duration.inSeconds / Duration.secondsPerHour;

  double? get hoursPerUnit =>
      task.effortQuantity != null && task.effortUnit.isNotEmpty
      ? hours / task.effortQuantity!
      : null;
}

/// Historical effort uses all finished time, including non-billable time.
/// No money or billing state is inferred from these comparison figures.
class TaskEffortHistory {
  Future<List<TaskEffortRecord>> load({String search = ''}) async {
    final rows = await DaoTask().withoutTransaction().rawQuery(
      '''
SELECT t.*, j.summary AS job_summary, c.name AS category_name,
       te.start_time AS effort_start, te.end_time AS effort_end
FROM task t
JOIN job j ON j.id = t.job_id
LEFT JOIN category c ON c.id = t.category_id
LEFT JOIN time_entry te ON te.task_id = t.id AND te.end_time IS NOT NULL
WHERE t.task_status_id = ? AND COALESCE(j.is_stock, 0) = 0
ORDER BY t.modifiedDate DESC, t.id, te.start_time
''',
      [TaskStatus.completed.id],
    );
    final records = <int, TaskEffortRecord>{};
    final query = search.trim().toLowerCase();
    for (final row in rows) {
      final task = Task.fromMap(row);
      final category = row['category_name'] as String? ?? 'Uncategorised';
      final summary = row['job_summary'] as String? ?? '';
      if (![
        task.name,
        summary,
        category,
        task.effortUnit,
        task.effortNotes,
      ].join(' ').toLowerCase().contains(query)) {
        continue;
      }
      final start = DateTime.tryParse(row['effort_start'] as String? ?? '');
      final end = DateTime.tryParse(row['effort_end'] as String? ?? '');
      final valid = start != null && end != null && !end.isBefore(start);
      final prior = records[task.id];
      records[task.id] = TaskEffortRecord(
        task: task,
        jobSummary: summary,
        category: category,
        duration:
            (prior?.duration ?? Duration.zero) +
            (valid ? end.difference(start) : Duration.zero),
        completedEntries: (prior?.completedEntries ?? 0) + (valid ? 1 : 0),
      );
    }
    return records.values.toList();
  }
}
