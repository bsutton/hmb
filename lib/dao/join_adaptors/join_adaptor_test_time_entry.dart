/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:sqflite_common/sqlite_api.dart';

import '../../entity/task.dart';
import '../../entity/time_entry.dart';
import '../dao_time_entry.dart';
import 'dao_join_adaptor.dart';

class JoinAdaptorTaskTimeEntry extends DaoJoinAdaptor<TimeEntry, Task> {
  @override
  Future<void> deleteFromParent(TimeEntry child, Task parent) async {
    // await DaoTimeEntryTask().deleteJoin(task, timeEntry);
    // there is no join table.
  }

  @override
  Future<List<TimeEntry>> getByParent(Task? parent) =>
      DaoTimeEntry().getByTask(parent?.id);

  @override
  Future<void> insertForParent(
    TimeEntry child,
    Task parent,
    Transaction transaction,
  ) async {
    // await DaoTimeEntry().insertForTask(timeEntry, task);
  }

  @override
  Future<void> setAsPrimary(TimeEntry child, Task parent) {
    // not used.
    throw UnimplementedError();
  }
}
