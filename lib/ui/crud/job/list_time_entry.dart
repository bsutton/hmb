import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/_index.g.dart';
import '../../../entity/_index.g.dart';
import '../../../util/format.dart';

class TimeEntryListScreen extends StatefulWidget {
  const TimeEntryListScreen({required this.job, super.key});

  final Job job;

  @override
  State<TimeEntryListScreen> createState() => _TimeEntryListScreenState();
}

class _TimeEntryListScreenState extends DeferredState<TimeEntryListScreen> {
  late Future<List<TimeEntry>> _timeEntries;

  @override
  Future<void> asyncInitState() async {
    await _refreshTimeEntries();
  }

  Future<void> _refreshTimeEntries() async {
    setState(() {
      _timeEntries = _fetchAndSortTimeEntries();
    });
  }

  Future<List<TimeEntry>> _fetchAndSortTimeEntries() async {
    final entries = await DaoTimeEntry().getByJob(widget.job.id);
    entries.sort(
        (a, b) => a.startTime.compareTo(b.startTime)); // Sort by start time
    return entries;
  }

  Duration _calculateTotalDuration(List<TimeEntry> timeEntries) =>
      timeEntries.fold<Duration>(
        Duration.zero,
        (total, entry) => total + entry.duration,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Time Entries for Job: ${widget.job.summary}'),
        ),
        body: FutureBuilderEx<List<TimeEntry>>(
          future: _timeEntries,
          builder: (context, timeEntries) {
            if (timeEntries!.isEmpty) {
              return const Center(child: Text('No time entries found.'));
            }

            final totalDuration = _calculateTotalDuration(timeEntries);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Total Hours Worked: ${totalDuration.inHours}h ${totalDuration.inMinutes.remainder(60)}m',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: timeEntries.length,
                    itemBuilder: (context, index) {
                      final timeEntry = timeEntries[index];
                      return FutureBuilderEx<Task?>(
                        // ignore: discarded_futures
                        future: DaoTask().getById(timeEntry.taskId),
                        waitingBuilder: (context) =>
                            const ListTile(title: Text('Loading task...')),
                        builder: (context, task) {
                          if (task == null) {
                            return const ListTile(
                              title: Text('Task not found'),
                            );
                          }
                          return TimeEntryTile(
                            timeEntry: timeEntry,
                            taskName: task.name,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class TimeEntryTile extends StatelessWidget {
  const TimeEntryTile({
    required this.timeEntry,
    required this.taskName,
    super.key,
  });

  final TimeEntry timeEntry;
  final String taskName;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          title: Text(
            'Task: $taskName',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start Time: ${formatDateTime(timeEntry.startTime)}'),
              Text(
                  'End Time: ${timeEntry.endTime != null ? formatDateTime(timeEntry.endTime!) : "Ongoing"}'),
              Text('Duration: ${formatDuration(timeEntry.duration)}'),
              if (timeEntry.note != null && timeEntry.note!.isNotEmpty)
                Text('Note: ${timeEntry.note}'),
              Text('Billed: ${timeEntry.billed ? "Yes" : "No"}'),
            ],
          ),
          trailing: timeEntry.invoiceLineId != null
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.hourglass_empty, color: Colors.grey),
        ),
      );
}
