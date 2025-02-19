import '../entity/system.dart';
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
}
