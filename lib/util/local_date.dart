/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:strings/strings.dart';

import 'date_time_ex.dart';
import 'format.dart';
import 'local_time.dart';

/// Provides a class which wraps a DateTime but just supplies the date
///  component.
@immutable
class LocalDate {
  /// Creates a [LocalDate] with the date set to today's date.
  /// This is the same as calling [LocalDate()].
  /// required by json.
  LocalDate(int year, [int month = 1, int day = 1])
    : date = DateTime(year, month, day);

  /// Creates a [LocalDate] with todays date.
  LocalDate.today() : date = stripTime(DateTime.now());

  /// Creates a ]LocalDate] by taking the date component of the past
  /// DateTime.
  LocalDate.fromDateTime(DateTime dateTime) : date = stripTime(dateTime);

  factory LocalDate.parse(String date) =>
      LocalDate.fromDateTime(DateTime.parse(date));

  static LocalDate? tryParse(String date) {
    final dateTime = DateTime.tryParse(date);

    if (dateTime == null) {
      return null;
    } else {
      return LocalDate.fromDateTime(dateTime);
    }
  }

  final DateTime date;

  int get weekday => date.weekday;

  int get year => date.year;

  int get month => date.month;

  int get day => date.day;

  /// Converts a LocalDate to a DateTime.
  /// If you passed in [time] then
  /// That time is set as the time component
  /// on the resulting DateTime.
  /// If [time] is null then the time component
  /// is set to midnight at the start of this
  /// [LocalDate].
  DateTime toDateTime({LocalTime? time}) => DateTime(
    date.year,
    date.month,
    date.day,
    time?.hour ?? 0,
    time?.minute ?? 0,
    time?.second ?? 0,
  );

  static DateTime stripTime(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);

  bool isAfter(LocalDate rhs) => date.isAfter(rhs.date);

  bool isAfterOrEqual(LocalDate rhs) => isAfter(rhs) || isEqual(rhs);

  bool isBefore(LocalDate rhs) => date.isBefore(rhs.date);

  bool isBeforeOrEqual(LocalDate rhs) => isBefore(rhs) || isEqual(rhs);

  bool isEqual(LocalDate rhs) => date.compareTo(rhs.date) == 0;

  @override
  bool operator ==(Object other) => other is LocalDate && isEqual(other);

  LocalDate addDays(int days) =>
      // We use this method to avoid problems with DST transitions
      // where a day is longer or shorer than 24 hrs
      LocalDate.fromDateTime(DateTime(date.year, date.month, date.day + days));

  LocalDate subtractDays(int days) =>
      // We use this method to avoid problems with DST transitions
      // where a day is longer or shorer than 24 hrs
      LocalDate.fromDateTime(DateTime(date.year, date.month, date.day - days));

  LocalDate add(Duration duration) =>
      LocalDate.fromDateTime(date.add(duration));

  /// returns the no. of days between this date and the
  /// passed [other] date.
  int daysBetween(LocalDate other) => date.difference(other.date).inDays;

  @override
  int get hashCode => date.hashCode;

  bool get isToday => date.toLocalDate() == LocalDate.today();

  LocalDate subtract(Duration duration) =>
      date.subtract(duration).toLocalDate();

  String toIso8601String() => date.toIso8601String();

  Duration difference(LocalDate other) => date.difference(other.toDateTime());

  LocalDate addMonths(int months) {
    // 1) total months since year-0:
    final total = (date.year * 12 + (date.month - 1)) + months;
    // 2) new year & month:
    final newYear = total ~/ 12;
    final newMonth = total % 12 + 1;
    // 3) find last day of that month:
    final lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    // 4) clamp the day:
    final newDay = date.day <= lastDayOfNewMonth ? date.day : lastDayOfNewMonth;
    return LocalDate(newYear, newMonth, newDay);
  }

  @override
  String toString() => formatLocalDate(this);
}

class LocalDateConverter implements JsonConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromJson(String? json) => Strings.isBlank(json)
      ? LocalDate.today()
      : LocalDate.fromDateTime(DateTime.parse(json!));

  @override
  String toJson(LocalDate? date) =>
      date == null ? '' : date.toDateTime().toIso8601String();
}

class LocalDateNullableConverter implements JsonConverter<LocalDate?, String?> {
  const LocalDateNullableConverter();

  @override
  LocalDate? fromJson(String? json) =>
      json == null ? null : LocalDate.fromDateTime(DateTime.parse(json));

  @override
  String? toJson(LocalDate? date) => date?.toDateTime().toIso8601String();
}
