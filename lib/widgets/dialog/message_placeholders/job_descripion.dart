import '../job_source.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';

class JobDescription extends PlaceHolder<String> {
  final JobSource jobSource;

  JobDescription({required this.jobSource}) : super(name: 'job.description', key: 'job');

  @override
  Future<String> value(MessageData data) async {
    final job = jobSource.value;
    return job?.description ?? '';
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
