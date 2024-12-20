import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import 'format.dart';
import 'local_date.dart';

/// Provides a class which wraps a DateTime but just supplies
/// the time component.
@immutable
class LocalTime {
  const LocalTime({required this.hour, required this.minute, this.second = 0});

  LocalTime.fromDateTime(DateTime dateTime)
      : hour = dateTime.hour,
        minute = dateTime.minute,
        second = dateTime.second;
  final int hour;
  final int minute;
  final int second;

  DateTime toDateTime() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day, hour, minute, second);
  }

  static DateTime stripDate(DateTime dateTime) => DateTime(
      0,
      0,
      0,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
      dateTime.millisecond,
      dateTime.microsecond);

  // ignore: prefer_constructors_over_static_methods
  static LocalTime now() {
    final now = DateTime.now();

    return LocalTime(hour: now.hour, minute: now.minute, second: now.second);
  }

  LocalTime addDuration(Duration duration) =>
      LocalTime.fromDateTime(toDateTime().add(duration));

  bool isAfter(LocalTime rhs) =>
      hour > rhs.hour ||
      (hour == rhs.hour && minute > rhs.minute) ||
      (hour == rhs.hour && minute == rhs.minute && second > rhs.second);

  bool isAfterOrEqual(LocalTime rhs) => isAfter(rhs) || isEqual(rhs);

  bool isBefore(LocalTime rhs) => !isAfter(rhs) && !isEqual(rhs);

  bool isBeforeOrEqual(LocalTime rhs) => isBefore(rhs) || isEqual(rhs);

  bool isEqual(LocalTime rhs) =>
      hour == rhs.hour && minute == rhs.minute && second == rhs.second;

  DateTime atDate(LocalDate date) =>
      DateTime(date.year, date.month, date.day, hour, minute, second);

  @override
  String toString() => formatLocalTime(this);
}

class LocalTimeConverter implements JsonConverter<LocalTime, String> {
  const LocalTimeConverter();

  @override
  // DateTime parse MUST have a date so pass 1900/1/1 and then strip the date component.
  LocalTime fromJson(String? json) => json == null
      ? LocalTime.now()
      : LocalTime.fromDateTime(DateTime.parse('1900-01-01 $json'));

  @override
  String toJson(LocalTime? time) =>
      time == null ? '' : formatLocalTime(time, 'HH:mm:ss');
}
