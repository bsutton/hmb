import 'package:date_time_format/date_time_format.dart';
import 'package:intl/intl.dart';

import 'local_date.dart';
import 'local_time.dart';

String formatDate(DateTime dateTime, {String format = 'D, j M'}) =>
    DateTimeFormat.format(dateTime, format: format);

String formatDateTime(DateTime dateTime, {bool seconds = false}) {
  final format = 'D, j M, H:i${seconds ? ':s' : ''}';
  return DateTimeFormat.format(dateTime, format: format);
}

String formatDateTimeAM(DateTime dateTime, {bool seconds = false}) {
  final format = 'D, j M, h:i${seconds ? ':s' : ''} a';
  return DateTimeFormat.format(dateTime, format: format);
}

String formatDuration(Duration duration, {bool seconds = false}) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  final result = '${hours}h ${minutes}m';
  if (seconds) {
    final seconds = duration.inSeconds.remainder(60);
    return '$result ${seconds}s';
  }

  return result;
}

String formatLocalDate(LocalDate date, [String format = 'yyyy/MM/dd']) =>
    DateFormat(format).format(date.toDateTime());

String formatLocalTime(LocalTime time, [String format = 'h:mm:ss a']) =>
    formatTime(time.toDateTime(), format);

String formatTime(DateTime date, [String format = 'h:mm:ss a']) =>
    DateFormat(format).format(date);

// ignore: omit_obvious_property_types
DateFormat dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

DateTime? parseDateTime(String? value) => dateFormat.tryParse(value ?? '');
// DateTime.parse(dateTime, format: 'D, j M, H:i:s');

// var french = await Cultures.getCulture('au-AU');

//   final localClone = tm.ZonedDateTimePattern.createWithInvariantCulture(
//           'dddd yyyy-MM-dd HH:mm z') // 'dddd, dd MMM HH:mm:ss',
//       .parse(dateTime);

//   return localClone.getValueOrThrow().localDateTime.toDateTimeLocal();
// }
