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

import '../../entity/system.dart';
import 'local_date.dart';
import 'local_time.dart';

extension DateTimeEx on DateTime {
  LocalDate toLocalDate() => LocalDate.fromDateTime(this);
  LocalTime toLocalTime() => LocalTime.fromDateTime(this);

  /// Sets the time component of this [DateTime] to [time].
  DateTime withTime(LocalTime time) => copyWith(
    hour: time.hour,
    minute: time.minute,
    second: time.second,
    microsecond: 0,
    millisecond: 0,
  );

  bool get isWeekEnd =>
      weekday - 1 == DayName.sat.index || weekday - 1 == DayName.sun.index;

  bool isAfterOrEqual(DateTime other) => isAfter(other) || this == other;

  /// True if this and [other] share the same yyyy-mm-dd.
  bool sameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}
