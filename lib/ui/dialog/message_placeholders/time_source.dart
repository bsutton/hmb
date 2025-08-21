/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../util/local_time.dart';
import '../../widgets/hmb_date_time_picker.dart';
import '../source_context.dart';
import 'source.dart';

class TimeSource extends Source<LocalTime> {
  final String label;

  LocalTime? localTime;

  TimeSource({required this.label}) : super(name: 'time');

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
