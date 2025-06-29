/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../../dao/dao_time_entry.dart';
import '../../../entity/task.dart';
import '../../../entity/time_entry.dart';
import '../../../util/format.dart';
import '../../widgets/layout/hmb_row_gap.dart';
import '../base_nested/list_nested_screen.dart';
import 'edit_time_entry_screen.dart';

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
      '''Interval: ${formatDateTime(entity.startTime)} - ${entity.endTime != null ? formatDateTime(entity.endTime!) : 'running'}; ${entity.note}''',
    ),
    onEdit: (timeEntry) =>
        TimeEntryEditScreen(task: parent.parent!, timeEntry: timeEntry),
    canEdit: (timeEntry) => !timeEntry.billed,
    // ignore: discarded_futures
    onDelete: (timeEntry) => DaoTimeEntry().delete(timeEntry.id),
    canDelete: (timeEntry)  => !timeEntry.billed,
    // ignore: discarded_futures
    onInsert: (timeEntry, transaction) =>
        DaoTimeEntry().insert(timeEntry, transaction),
    details: (timeEntry, details) => Row(
      children: [
        Text('Billed: ${timeEntry.billed}'),
        const HMBRowGap(),
        Text(
          '''Duration: ${timeEntry.endTime == null ? 'running' : formatDuration(timeEntry.endTime!.difference(timeEntry.startTime))}''',
        ),
      ],
    ),
  );
}
