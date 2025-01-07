import '../entity/system.dart';
import 'local_date.dart';
import 'local_time.dart';

extension DateTimeEx on DateTime {
  LocalDate toLocalDate() => LocalDate.fromDateTime(this);
  LocalTime toLocalTime() => LocalTime.fromDateTime(this);

  bool get isWeekEnd =>
      weekday - 1 == DayName.sat.index || weekday - 1 == DayName.sun.index;

  bool isAfterOrEqual(DateTime other) => isAfter(other) || this == other;
}
