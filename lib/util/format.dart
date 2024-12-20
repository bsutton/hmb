import 'package:date_time_format/date_time_format.dart';
import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:intl/intl.dart';
import 'package:strings/strings.dart';

import '../dao/dao_system.dart';
import 'local_date.dart';
import 'local_time.dart';

String formatDate(DateTime dateTime, {String format = 'D, j M'}) =>
    DateTimeFormat.format(dateTime, format: format);

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

String formatLocalDate(LocalDate date, [String pattern = 'yyyy/MM/dd']) =>
    DateFormat(pattern).format(date.toDateTime());

String formatLocalTime(LocalTime time, [String pattern = 'h:mm:ss a']) =>
    formatTime(time.toDateTime(), pattern);

String formatTime(DateTime date, [String pattern = 'h:mm:ss a']) =>
    DateFormat(pattern).format(date);

DateFormat dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

DateTime? parseDateTime(String? value) => dateFormat.tryParse(value ?? '');
// DateTime.parse(dateTime, format: 'D, j M, H:i:s');

// var french = await Cultures.getCulture('au-AU');

//   final localClone = tm.ZonedDateTimePattern.createWithInvariantCulture(
//           'dddd yyyy-MM-dd HH:mm z') // 'dddd, dd MMM HH:mm:ss',
//       .parse(dateTime);

//   return localClone.getValueOrThrow().localDateTime.toDateTimeLocal();
// }

Future<String> formatPhone(String? phone) async {
  if (Strings.isBlank(phone)) {
    return '';
  }
  final phoneUtil = PhoneNumberUtil.instance;

  final system = await DaoSystem().get();

  String formatted;

  try {
    final phoneNumber = phoneUtil.parse(phone, system!.countryCode ?? 'AU');
    formatted = phoneUtil.format(phoneNumber, PhoneNumberFormat.national);
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    formatted = phone ?? '';
  }
  return formatted;
}
