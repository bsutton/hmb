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

/// Returns a compact human label for a due date.
/// Examples:
///  - Overdue 2h
///  - Overdue 3d
///  - Today 09:30
///  - Tomorrow 14:00
///  - Thu 08:15
///  - 18 Aug
///  - 18 Aug 2026   // different year
String formatDue(DateTime due, {DateTime? now, bool includeTime = true}) {
  final n = (now ?? DateTime.now()).toLocal();
  final d = due.toLocal();

  final atMidnight = DateTime(d.year, d.month, d.day);
  final nowMidnight = DateTime(n.year, n.month, n.day);

  final dayDelta = atMidnight.difference(nowMidnight).inDays;

  // Overdue
  if (d.isBefore(n)) {
    final age = _compactAge(n.difference(d));
    return age == null ? 'Overdue' : 'Overdue $age';
  }

  // Today / Tomorrow / Next 6 days -> weekday
  if (dayDelta == 0) {
    final t = includeTime ? _hm(d) : '';
    return t.isEmpty ? 'Today' : 'Today $t';
  }
  if (dayDelta == 1) {
    final t = includeTime ? _hm(d) : '';
    return t.isEmpty ? 'Tomorrow' : 'Tomorrow $t';
  }
  if (dayDelta >= 2 && dayDelta <= 6) {
    final t = includeTime ? ' ${_hm(d)}' : '';
    return '${_wk(d.weekday)}$t';
  }

  // Beyond a week: 18 Aug or 18 Aug 2026 if year differs
  final base = '${_dd(d.day)} ${_mon(d.month)}';
  if (d.year != n.year) {
    return '$base ${d.year}';
  }
  return base;
}



/// Returns a compact age like "5m", "2h", "3d".
/// Returns null if under 1 minute (too small to show).
String? _compactAge(Duration d) {
  final mins = d.inMinutes;
  if (mins < 1) {
    return null;
  }
  if (mins < 60) {
    return '${mins}m';
  }
  final hours = d.inHours;
  if (hours < 24) {
    return '${hours}h';
  }
  final days = d.inDays;
  return '${days}d';
}

String _dd(int day) => day < 10 ? '0$day' : '$day';

String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String _two(int v) => v < 10 ? '0$v' : '$v';

String _wk(int weekday) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  // DateTime.weekday: Mon=1..Sun=7
  return names[(weekday - 1) % 7];
}

String _mon(int month) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return m[(month - 1).clamp(0, 11)];
}

/// Convenience if you need a boolean check elsewhere.
bool isOverdue(DateTime? due, {DateTime? now}) {
  if (due == null) {
    return false;
  }
  final n = (now ?? DateTime.now()).toLocal();
  return due.toLocal().isBefore(n);
}
