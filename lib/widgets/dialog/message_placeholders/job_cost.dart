import '../../../dao/dao_job.dart';
import '../job_source.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';

class JobCost extends PlaceHolder<String> {
  final JobSource jobSource;

  JobCost({required this.jobSource}) : super(name: 'job.cost', key: 'job');

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
  PlaceHolderField<String> field(MessageData data) {
    // No field needed; value comes from jobSource
    return PlaceHolderField(
      placeholder: this,
      widget: null,
      getValue: (data) async => value(data),
    );
  }

  @override
  void setValue(String? value) {
    // Not used; value comes from jobSource
  }
}
