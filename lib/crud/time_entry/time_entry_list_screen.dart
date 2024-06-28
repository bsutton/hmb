import 'package:flutter/material.dart';

import '../../dao/dao_time_entry.dart';
import '../../entity/task.dart';
import '../../entity/time_entry.dart';
import '../../util/format.dart';
import '../base_nested/nested_list_screen.dart';
import 'time_entry_edit_screen.dart';

class TimeEntryListScreen extends StatelessWidget {
  const TimeEntryListScreen({required this.parent, super.key});

  final Parent<Task> parent;

  @override
  Widget build(BuildContext context) => NestedEntityListScreen<TimeEntry, Task>(
      parent: parent,
      entityNamePlural: 'Time Entries',
      entityNameSingular: 'Time Entry',
      parentTitle: 'Task',
      dao: DaoTimeEntry(),
      // ignore: discarded_futures
      fetchList: () => DaoTimeEntry().getByTask(parent.parent?.id),
      title: (entity) => Text(
          '''Interval: ${formatDateTime(entity.startTime)} - ${entity.endTime != null ? formatDateTime(entity.endTime!) : 'running'}'''),
      onEdit: (timeEntry) =>
          TimeEntryEditScreen(task: parent.parent!, timeEntry: timeEntry),
      onDelete: (timeEntry) async => DaoTimeEntry().delete(timeEntry!.id),
      onInsert: (timeEntry) async => DaoTimeEntry().insert(timeEntry!),
      details: (timeEntry, details) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '''Duration: ${timeEntry.endTime == null ? 'running' : formatDuration(timeEntry.endTime!.difference(timeEntry.startTime))}'''),
            ],
          ));
}
