import 'package:date_time_format/date_time_format.dart';

String formatDate(DateTime dateTime) =>
    DateTimeFormat.format(dateTime, format: 'D, j M');

String formatDateTime(DateTime dateTime, {bool seconds = false}) {
  final format = 'D, j M, H:i${seconds ? ':s' : ''}';
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

// DateTime parseDateTime(String dateTime) {
//   // DateTime.parse(dateTime, format: 'D, j M, H:i:s');

// // var french = await Cultures.getCulture('au-AU');

//   final localClone = tm.ZonedDateTimePattern.createWithInvariantCulture(
//           'dddd yyyy-MM-dd HH:mm z') // 'dddd, dd MMM HH:mm:ss',
//       .parse(dateTime);

//   return localClone.getValueOrThrow().localDateTime.toDateTimeLocal();
// }
