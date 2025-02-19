import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../util/local_time.dart';
import '../../widgets/hmb_date_time_picker.dart';
import '../source_context.dart';
import 'source.dart';

class TimeSource extends Source<LocalTime> {
  TimeSource({required this.label}) : super(name: 'time');

  final String label;

  LocalTime? localTime;

  @override
  Widget widget() => HMBDateTimeField(
    label: label.toProperCase(),
    initialDateTime: DateTime.now(),
    onChanged: (datetime) {
      localTime = LocalTime.fromDateTime(datetime);
    },
    mode: HMBDateTimeFieldMode.timeOnly,
  );

  @override
  LocalTime? get value => localTime;

  @override
  void dependencyChanged(Source<dynamic> source, SourceContext sourceContext) {
    // NO OP
  }

  @override
  void revise(SourceContext sourceContext) {
    // NO OP
  }
}
