import '../util/local_time.dart';
import 'system.dart';

class OperatingDay {
  // e.g. "17:00"

  OperatingDay({
    required this.dayName,
    this.start,
    this.end,
    this.open = true,
  });

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
  final DayName dayName;
  LocalTime? start; // e.g. "08:00"
  LocalTime? end;
  bool open;

  /// Convert this OperatingDay instance back to a JSON-like map.
  Map<String, dynamic> toJson() => {
        'dayName': dayName.toJson(),
        'start': const LocalTimeConverter().toJson(start),
        'end': const LocalTimeConverter().toJson(end),
        'open': open ? 1 : 0,
      };
}
