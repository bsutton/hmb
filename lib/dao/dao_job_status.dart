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
}

/// Used to notify the UI that the time entry has changed.
class JobStatusState extends JuneState {
  JobStatusState();
}
