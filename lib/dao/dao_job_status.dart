/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:june/june.dart';

import '../entity/job_status.dart';
import 'dao.dart';

class DaoJobStatus extends Dao<JobStatus> {
  @override
  String get tableName => 'job_status';

  @override
  JobStatus fromMap(Map<String, dynamic> map) => JobStatus.fromMap(map);
  @override
  JuneStateCreator get juneRefresher => JobStatusState.new;

  Future<JobStatus?> getByName(String name) async {
    final data = await db.query(
      'job_status', // Table name
      where: 'name = ?', // SQL WHERE clause
      whereArgs: [name], // Arguments for the WHERE clause
    );

    if (data.isEmpty) {
      return null; // Return null if no job status is found
    }

    return JobStatus.fromMap(data.first); // Convert the first row to JobStatus
  }

  Future<JobStatus?> getInProgress() => getByName('In Progress');
  Future<JobStatus?> getQuoting() => getByName('Quoting');
}

/// Used to notify the UI that the time entry has changed.
class JobStatusState extends JuneState {
  JobStatusState();
}
