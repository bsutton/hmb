import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../util/local_date.dart';
import '../../widgets/hmb_date_time_picker.dart';
import '../source_context.dart';
import 'source.dart';

class DateSource extends Source<LocalDate> {
  DateSource({required this.label}) : super(name: 'date');

  final String label;

  LocalDate? date;

  @override
  Widget widget() => HMBDateTimeField(
    mode: HMBDateTimeFieldMode.dateOnly,
    label: label.toProperCase(),
    initialDateTime: DateTime.now(),
    onChanged: (datetime) {
      date = LocalDate.fromDateTime(datetime);
      super.onChanged(value, ResetFields());
    },
  );

  @override
  LocalDate? get value => date;

  @override
  void dependencyChanged(Source<dynamic> source, SourceContext sourceContext) {
    // no op
  }
  @override
  void revise(SourceContext sourceContext) {
    // no op
  }
}
