import 'local_date.dart';
import 'local_time.dart';

extension DateTimeEx on DateTime {
  LocalDate toLocalDate() => LocalDate.fromDateTime(this);
  LocalTime toLocalTime() => LocalTime.fromDateTime(this);
}
