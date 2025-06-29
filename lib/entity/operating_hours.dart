/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:convert';

import '../dao/dao_job_activity.dart';
import '../util/date_time_ex.dart';
import '../util/local_date.dart';
import '../util/local_time.dart';
import 'job_activity.dart';
import 'operating_day.dart';
import 'system.dart';

class OperatingHours {
  OperatingHours({required this.days}) {
    final missing = <DayName>[];
    // back fill any missing days
    // this is required when we first populate the system table
    for (final day in DayName.values) {
      if (!days.containsKey(day)) {
        missing.add(day);
      }
    }

    for (final missed in missing) {
      days[missed] = OperatingDay(
        dayName: missed,
        start: const LocalTime(hour: 9, minute: 0),
        end: const LocalTime(hour: 17, minute: 0),
      );
    }
  }

  /// Builds an OperatingHours instance from a JSON string.
  /// If the string is null/empty, returns an empty list.
  factory OperatingHours.fromJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) {
      return OperatingHours(days: <DayName, OperatingDay>{});
    }

    final decoded = jsonDecode(jsonStr) as List<dynamic>;
    // Convert the decoded list into a Map keyed by `DayName`.
    final dayMap = {
      for (final item in decoded)
        OperatingDay.fromJson(item as Map<String, dynamic>).dayName:
            OperatingDay.fromJson(item),
    };

    return OperatingHours(days: dayMap);
  }

  /// A Map of  OperatingDay objects, one for each day you operate.
  /// The key is the short day name. e.g. Mon
  ///
  final Map<DayName, OperatingDay> days;

  /// Converts the OperatingHours instance back to a JSON string.
  String toJson() {
    // Convert the map values (OperatingDay) to a list of maps (JSON format).
    final listToEncode = days.values
        .map((operatingDay) => operatingDay.toJson())
        .toList();
    return jsonEncode(listToEncode);
  }

  /// Get the [OperatingDay] for the [dayName]
  OperatingDay day(DayName dayName) => days[dayName]!;

  /// True if at least one day of the week is marked as open.
  bool noOpenDays() => openList.where((open) => open).toList().isEmpty;

  /// An ordered list of the days that we are open - starting from monday
  List<bool> get openList =>
      days.values.map<bool>((hours) => hours.open).toList();

  /// True if the opening hours incude sat or sun
  bool openOnWeekEnd() =>
      openList[DayName.sat.index] || openList[DayName.sun.index];

  Future<bool> isOpen(LocalDate targetDate) async {
    final dayOfWeek = targetDate.date.weekday;

    var open = isDayOfWeekOpen(dayOfWeek);

    if (!open) {
      /// if the day isn't normally open we still need
      /// to check for activities scheduled out of normal hours.

      /// special check for an activiity on the out of hours day.
      open = (await DaoJobActivity().getActivitiesInRange(
        targetDate,
        targetDate.addDays(1),
      )).isNotEmpty;
    }
    return open;
  }

  bool isDayOfWeekOpen(int dayOfWeek) {
    final dayName = DayName.fromWeekDay(dayOfWeek);
    final operatingDay = day(dayName);

    return operatingDay.open;
  }

  Future<LocalDate> getNextOpenDate(LocalDate currentDate) async {
    // Start from the current date
    var date = currentDate;

    // Loop for a maximum of 7 days (one week) to find the next open day
    for (var i = 0; i < 7; i++) {
      // Check if the current day is open
      if (await isOpen(date)) {
        return date; // Return the first open day
      }

      // Move to the next day
      date = date.addDays(1);
    }

    // If no open day is found within the next 7 days (unlikely), throw an error
    throw StateError('No open days found within the next week.');
  }

  /// Example implementation for going backward to the previous open date.
  /// Similar logic to getNextOpenDate but in reverse.
  Future<LocalDate> getPreviousOpenDate(LocalDate fromDate) async {
    // Try up to 7 days backward (or whatever limit you prefer)
    var date = fromDate;
    for (var i = 0; i < 7; i++) {
      if (await isOpen(date)) {
        return date;
      }
      date = date.subtractDays(1);
    }
    // If everything is closed for a whole week, handle gracefully or throw:
    throw StateError('No open day found within the past 7 days.');
  }

  /// True if the [activity] is fully within the normal operating hours.

  bool inOperatingHours(JobActivity activity) {
    // 1) Check if the activity is on a single day.
    //    If it spans multiple calendar days, return false (or handle specially).
    if (activity.start.toLocalDate() != activity.end.toLocalDate()) {
      return false;
    }

    // 2) Ensure that day is open in OperatingHours.
    //    If it's closed, return false right away.
    final dayOfWeek = activity.start.weekday; // Monday=1, Sunday=7
    if (!isDayOfWeekOpen(dayOfWeek)) {
      return false;
    }

    // 3) Retrieve the OperatingDay for that weekday.
    final dayName = DayName.fromWeekDay(dayOfWeek);
    final operatingDay = day(dayName);

    // If, for some reason, `operatingDay.open` is false, return false.
    if (!operatingDay.open) {
      return false;
    }

    // 4) Compare the activities time range to the day’s start/end times.
    //    If either start or end is null, treat as “no configured hours,” i.e., closed.
    if (operatingDay.start == null || operatingDay.end == null) {
      return false;
    }

    // 5) Check that the activity starts after (or exactly at) opening
    //    AND ends before (or exactly at) closing.
    final activityStart = activity.start.toLocalTime();
    final activityEnd = activity.end.toLocalTime();
    final openTime = operatingDay.start!;
    final closeTime = operatingDay.end!;

    final startsTooEarly = activityStart.isBefore(openTime);
    final endsTooLate = activityEnd.isAfter(closeTime);

    if (startsTooEarly || endsTooLate) {
      return false;
    }

    return true;
  }

  /// Returns the opening time for the given date
  /// or 7am if no stated openting time.
  LocalTime openingTime(LocalDate date) =>
      day(DayName.fromDate(date)).start ?? const LocalTime(hour: 7, minute: 0);
}
