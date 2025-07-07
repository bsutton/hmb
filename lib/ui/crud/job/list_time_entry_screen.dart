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
import '../../widgets/help_button.dart';
import '../../widgets/select/hmb_select_task.dart';
import '../../widgets/select/select.g.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_time_entry_screen.dart';

class TimeEntryListScreen extends StatefulWidget {
  const TimeEntryListScreen({required this.job, super.key});

  final Job job;

  @override
  State<TimeEntryListScreen> createState() => _TimeEntryListScreenState();
}

class _TimeEntryListScreenState extends State<TimeEntryListScreen> {
  final _supplierFilter = SelectedSupplier();
  final _taskFilter = SelectedTask();
  DateTime? _selectedDate;

  Future<List<TimeEntry>> _fetchFiltered(String? search) async {
    var list = await DaoTimeEntry().getByJob(widget.job.id);
    // search in notes
    if (search != null && search.isNotEmpty) {
      list = list
          .where(
            (e) => (e.note?.toLowerCase() ?? '').contains(search.toLowerCase()),
          )
          .toList();
    }
    // supplier filter
    if (_supplierFilter.selected != null) {
      list = list
          .where((e) => e.supplierId == _supplierFilter.selected)
          .toList();
    }

    // task filter
    if (_taskFilter.taskId != null) {
      list = list.where((e) => e.taskId == _taskFilter.taskId).toList();
    }
    // date filter (by startTime on same day)
    if (_selectedDate != null) {
      final sel = _selectedDate!;
      list = list.where((e) {
        final dt = e.startTime;
        return dt.year == sel.year &&
            dt.month == sel.month &&
            dt.day == sel.day;
      }).toList();
    }
    return list;
  }

  Widget _buildFilterSheet(BuildContext context) => StatefulBuilder(
    builder: (context, sheetSetState) => ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      children: [
        HMBSelectTask(
          selectedTask: _taskFilter,
          job: widget.job,
          onSelected: (task) {
            _taskFilter.taskId = task?.id;
            sheetSetState(() {});
          },
        ),

        HMBSelectSupplier(
          selectedSupplier: _supplierFilter,
          onSelected: (sup) async {
            _supplierFilter.selected = sup?.id;
            sheetSetState(() {});
          },
        ).help(
          'Filter by Supplier',
          'Only show entries for the chosen supplier',
        ),
        const SizedBox(height: 16),
        ListTile(
          key: ValueKey(_selectedDate),
          title: const Text('Date'),
          subtitle: Text(
            _selectedDate != null ? formatDate(_selectedDate!) : 'Select date',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              initialDate: _selectedDate ?? DateTime.now(),
            );
            if (picked != null) {
              _selectedDate = picked;
              sheetSetState(() {});
            }
          },
        ),
      ],
    ),
  );

  void _clearAllFilters() {
    setState(() {
      _supplierFilter.selected = null;
      _taskFilter.taskId = null;
      _selectedDate = null;
    });
  }

  Future<Widget> _getTitle(TimeEntry entry) async {
    final task = await DaoTask().getById(entry.taskId);
    return Text(
      '${formatDate(entry.startTime)} Task: ${task!.name}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Future<_Details> getDetails(TimeEntry entry) async {
    final task = await DaoTask().getById(entry.taskId);
    return _Details(task!, entry);
  }

  final _entityListKey = GlobalKey<EntityListScreenState>();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: EntityListScreen<TimeEntry>(
      key: _entityListKey,
      pageTitle: 'Time Entries',
      dao: DaoTimeEntry(),
      fetchList: _fetchFiltered,
      filterSheetBuilder: _buildFilterSheet,
      onFilterSheetClosed: () async =>
          await _entityListKey.currentState?.refresh(),
      onClearAll: _clearAllFilters,
      cardHeight: 220,
      title: (entry) async => _getTitle(entry),
      onEdit: (entry) => TimeEntryEditScreen(job: widget.job, timeEntry: entry),
      details: (entry) => FutureBuilderEx(
        future: getDetails(entry),
        builder: (context, detail) =>
            TimeEntryTile(timeEntry: entry, taskName: detail!.task.name),
      ),
    ),
  );
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
