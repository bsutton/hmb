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

// ignore_for_file: omit_obvious_property_types

import '../../../entity/job_activity.dart';
import '../../../util/dart/date_time_ex.dart';
import '../../../util/dart/format.dart';
import '../../../util/dart/local_date.dart';
import 'date_source.dart';
import 'place_holder.dart';

class JobActivityDate extends PlaceHolder<JobActivity> {
  static String tagName = 'job_activity.start_date';
  static const _tagBase = 'job_activity';
  static String label = 'Activity Date';

  JobActivityDate({required super.source})
    : super(name: tagName, base: _tagBase);

  @override
  Future<String> value() async =>
      formatLocalDate(source.value?.start.toLocalDate() ?? LocalDate.today());
}

class JobActivityTime extends PlaceHolder<JobActivity> {
  static String tagName = 'job_activity.start_time';
  static const _tagBase = 'job_activity';
  static String label = 'Activity Time';

  JobActivityTime({required super.source})
    : super(name: tagName, base: _tagBase);

  @override
  Future<String> value() async => source.value != null
      ? formatLocalTime(source.value!.start.toLocalTime())
      : '';
}

class OriginalDate extends PlaceHolder<LocalDate> {
  static String tagName = 'job_activity.original_date';
  static const _tagBase = 'job_activity.original_date';
  static String label = 'Original Date';

  DateSource dateSource;

  OriginalDate({required this.dateSource})
    : super(name: tagName, base: _tagBase, source: dateSource);

  @override
  Future<String> value() async => formatLocalDate(dateSource.date!);
}
