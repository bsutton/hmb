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

import '../../../util/dart/local_date.dart';
import '../../widgets/hmb_date_time_picker.dart';
import '../source_context.dart';
import 'source.dart';

class DateSource extends Source<LocalDate> {
  final String label;

  LocalDate? date;

  DateSource({required this.label}) : super(name: 'date');

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
