import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:strings/strings.dart';

import 'format.dart';
import 'local_date.dart';

/// Provides a class which wraps a DateTime but just supplies
/// the time component.
@immutable
class LocalTime {
  const LocalTime({required this.hour, required this.minute, this.second = 0});

  factory LocalTime.parse(String time) {
    // Utility: convert "08:00" to TimeOfDay
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return LocalTime(hour: hour, minute: minute);
  }

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
    dateTime.microsecond,
  );

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
  bool operator ==(covariant LocalTime other) {
    /// hour == 0 an hour == 24 are both 12 am.
    final thisHour = hour == 0 ? 24 : hour;
    final otherHour = other.hour == 0 ? 24 : other.hour;

    return thisHour == otherHour &&
        minute == other.minute &&
        second == other.second;
  }

  @override
  String toString() => formatLocalTime(this);

  @override
  int get hashCode =>
      /// hour == 0 an hour == 24 are both 12 am.
      Object.hashAll([if (hour == 0) 24 else hour, minute, second]);

  Duration difference(LocalTime startTime) {
    final today = LocalDate.today();
    return atDate(today).difference(startTime.atDate(today));
  }
}

class LocalTimeConverter implements JsonConverter<LocalTime, String> {
  const LocalTimeConverter();

  @override
  // DateTime parse MUST have a date so pass 1900/1/1 and then strip the date component.
  LocalTime fromJson(String? json) => Strings.isBlank(json)
      ? LocalTime.now()
      : LocalTime.fromDateTime(DateTime.parse('1900-01-01 $json'));

  @override
  String toJson(LocalTime? time) =>
      time == null ? '' : formatLocalTime(time, 'HH:mm:ss');
}
