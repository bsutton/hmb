import '../../../dao/dao_job.dart';
import '../message_template_dialog.dart';
import 'job_source.dart';
import 'place_holder.dart';

class JobCost extends PlaceHolder<String> {
  JobCost({required this.jobSource}) : super(name: keyName, key: keyScope);
  final JobSource jobSource;

  static String keyName = 'job.cost';
  static String keyScope = 'job';


  @override
  Future<String> value(MessageData data) async {
    final job = jobSource.value;
    if (job != null) {
      return (await DaoJob().getJobStatistics(job)).totalCost.toString();
    } else {
      return '';
    }
  }


  @override
  void setValue(String? value) {
    // Not used; value comes from jobSource
  }
}
