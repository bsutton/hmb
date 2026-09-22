import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../dao/dao_job.dart';
import '../../../dao/task_effort_history.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';
import 'edit_task_screen.dart';

class TaskEffortHistoryScreen extends StatefulWidget {
  const TaskEffortHistoryScreen({super.key});

  @override
  State<TaskEffortHistoryScreen> createState() =>
      _TaskEffortHistoryScreenState();
}

class _TaskEffortHistoryScreenState
    extends DeferredState<TaskEffortHistoryScreen> {
  final _search = TextEditingController();
  List<TaskEffortRecord> _records = [];

  @override
  Future<void> asyncInitState() => _load();

  Future<void> _load() async {
    final records = await BlockingUI().runAndWait(
      () => TaskEffortHistory().load(search: _search.text),
    );
    if (mounted) {
      setState(() => _records = records);
    }
  }

  Future<void> _edit(TaskEffortRecord record) async {
    final job = await BlockingUI().runAndWait(
      () => DaoJob().getById(record.task.jobId),
    );
    if (!mounted || job == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TaskEditScreen(job: job, task: record.task),
      ),
    );
    await _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Prior work effort',
    maxContentWidth: 800,
    child: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, _) => const Text('Could not load prior work.'),
      builder: (context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: HMBColumn(
              children: [
                const Text(
                  'Completed tasks and recorded time, including non-billable '
                  'work. Running timers are excluded. Compare similar work '
                  'and units; these are observations, not quoted rates.',
                ),
                HMBTextField(
                  controller: _search,
                  labelText: 'Search category, job, task, unit or notes',
                  suffixIcon: IconButton(
                    tooltip: 'Search prior work',
                    icon: const Icon(Icons.search),
                    onPressed: _load,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _records.isEmpty
                ? const Center(child: Text('No matching completed tasks.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      final task = record.task;
                      final rate = record.hoursPerUnit?.toStringAsFixed(2);
                      return Surface(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(task.name),
                          subtitle: Text(
                            [
                              'Job #${task.jobId}: ${record.jobSummary}',
                              record.category,
                              if (record.completedEntries == 0)
                                'No finished time recorded'
                              else
                                '${record.hours.toStringAsFixed(2)} hours',
                              if (task.effortQuantity != null)
                                '${task.effortQuantity} ${task.effortUnit}',
                              if (record.hoursPerUnit != null &&
                                  record.completedEntries > 0)
                                '$rate hours per ${task.effortUnit}',
                              if (task.effortNotes.isNotEmpty) task.effortNotes,
                            ].join('\n'),
                          ),
                          trailing: IconButton(
                            tooltip: 'Edit comparison details',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _edit(record),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
