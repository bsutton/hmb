/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/format.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_time_entry_screen.dart';

class TimeEntryListScreen extends StatefulWidget {
  const TimeEntryListScreen({required this.job, super.key});

  final Job job;

  @override
  State<TimeEntryListScreen> createState() => _TimeEntryListScreenState();
}

class _TimeEntryListScreenState extends State<TimeEntryListScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Time Entries')),
    body: EntityListScreen<TimeEntry>(
      cardHeight: 220,
      // parent: Parent(widget.job),
      pageTitle: 'Time Entries',
      // entityNameSingular: 'Time Entry',
      // entityNamePlural: 'Time Entries',
      dao: DaoTimeEntry(),
      // onDelete: (entry) => DaoTimeEntry().delete(entry.id),
      // onInsert: (entry, tx) => DaoTimeEntry().insert(entry, tx),
      fetchList: (filter) => DaoTimeEntry().getByJob(widget.job.id),
      title: (entry) async => _getTitle(entry),
      onEdit: (entry) => TimeEntryEditScreen(job: widget.job, timeEntry: entry),
      details: (entry) => FutureBuilderEx(
        future: getDetails(entry),
        builder: (context, detail) =>
            TimeEntryTile(timeEntry: entry, taskName: detail!.task.name),
      ),
    ),
  );

  Future<Widget> _getTitle(TimeEntry entry) async {
    final task = await DaoTask().getById(entry.taskId);

    return Text(
      '${formatDate(entry.startTime)} Task: ${task!.name} ',
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Future<_Details> getDetails(TimeEntry entry) async {
    final task = await DaoTask().getById(entry.taskId);

    return _Details(task!, entry);
  }
}

class _Details {
  _Details(this.task, this.timeEntry);
  Task task;
  TimeEntry timeEntry;
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
  Widget build(BuildContext context) => ListTile(
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (timeEntry.supplierId != null)
          FutureBuilderEx(
            future: DaoSupplier().getById(timeEntry.supplierId),
            builder: (context, supplier) => Text('Supplier: ${supplier!.name}'),
          ),
        Text('Start Time: ${formatDateTime(timeEntry.startTime)}'),
        Text(
          'End Time: ${timeEntry.endTime != null ? formatDateTime(timeEntry.endTime!) : "Ongoing"}',
        ),
        Text('Duration: ${formatDuration(timeEntry.duration)}'),
        if (timeEntry.note != null && timeEntry.note!.isNotEmpty)
          Text('Note: ${timeEntry.note}'),
        Text('Billed: ${timeEntry.billed ? "Yes" : "No"}'),
      ],
    ),
    trailing: timeEntry.invoiceLineId != null
        ? const Icon(Icons.receipt_long, color: Colors.green)
        : const Icon(Icons.receipt_long_outlined, color: Colors.grey),
  );
}
