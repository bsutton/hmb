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

import '../util/dart/local_time.dart';
import 'system.dart';

class OperatingDay {
  final DayName dayName;
  LocalTime? start;
  LocalTime? end;
  bool open;

  OperatingDay({required this.dayName, this.start, this.end, this.open = true});

  /// Construct from a JSON map, expecting:
  /// {
  ///   "dayName": "mon",
  ///   "start": "08:00",
  ///   "end": "17:00"
  /// }
  factory OperatingDay.fromJson(Map<String, dynamic> json) => OperatingDay(
    dayName: DayName.fromJson(json['dayName'] as String),
    start: const LocalTimeConverter().fromJson(json['start'] as String?),
    end: const LocalTimeConverter().fromJson(json['end'] as String?),
    open: ((json['open'] as int?) ?? 1) == 1,
  );

  /// Convert this OperatingDay instance back to a JSON-like map.
  Map<String, dynamic> toJson() => {
    'dayName': dayName.toJson(),
    'start': const LocalTimeConverter().toJson(start),
    'end': const LocalTimeConverter().toJson(end),
    'open': open ? 1 : 0,
  };
}
