import 'package:flutter/material.dart';

import '../../../entity/system.dart';
import '../../../util/format.dart';
import '../../../util/local_time.dart';
import '../../widgets/hmb_date_time_picker.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/text/hmb_text_themes.dart';

class OperatingHoursController {
  OperatingHoursController({required this.operatingHours});

  final OperatingHours operatingHours;
}

class OperatingHoursUi extends StatefulWidget {
  const OperatingHoursUi({required this.controller, super.key});

  final OperatingHoursController controller;

  @override
  State<OperatingHoursUi> createState() => _OperatingHoursUiState();
}

class _OperatingHoursUiState extends State<OperatingHoursUi> {
  @override
  void initState() {
    super.initState();

    // // For each OperatingDay in the existing schedule, populate local state
    // for (final od in widget.controller.operatingHours.days.values) {
    //   // Find the index in _dayOrder
    //   final i = _dayOrder.indexOf(od.dayName);
    //   if (i >= 0) {
    //     _selectedDays[i] = true;

    //     // Parse the string "08:00" into LocalTime if needed
    //     if (od.start != null) {
    //       _startTimes[od.dayName] = _stringToTimeOfDay(od.start!);
    //     }
    //     if (od.end != null) {
    //       _endTimes[od.dayName] = _stringToTimeOfDay(od.end!);
    //     }
    //   }
    // }
  }

  // // 2. Keep a Map of start/end times for each day
  // final Map<DayName, LocalTime?> _startTimes = {};

  // final Map<DayName, LocalTime?> _endTimes = {};

  // 3. In a known order for easy indexing
  final List<DayName> _dayOrder = [
    DayName.mon,
    DayName.tue,
    DayName.wed,
    DayName.thu,
    DayName.fri,
    DayName.sat,
    DayName.sun,
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operating Days and Hours',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          ToggleButtons(
            isSelected: widget.controller.operatingHours.openList,
            onPressed: (index) {
              setState(() {
                widget.controller.operatingHours.day(index).open =
                    !widget.controller.operatingHours.day(index).open;
              });
            },
            children: _dayOrder.map((d) => Text(d.shortName)).toList(),
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(_dayOrder.length, (index) {
              if (!widget.controller.operatingHours.day(index).open) {
                return const SizedBox.shrink();
              }

              final operatingHours = widget.controller.operatingHours;
              final day = operatingHours.days[DayName.values[index]]!;
              final start = day.start ??
                  LocalTime.fromDateTime(
                      DateTime.now().copyWith(hour: 9, minute: 0));
              final end = day.end ??
                  LocalTime.fromDateTime(
                      DateTime.now().copyWith(hour: 17, minute: 0));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HMBTextLabel(
                    day.dayName.shortName,
                    color: Colors.purpleAccent,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 200,
                        child: HMBDateTimeField(
                          initialDateTime: start.toDateTime(),
                          showDate: false,
                          onChanged: (date) async =>
                              day.start = LocalTime.fromDateTime(date),
                          label: 'Start',
                        ),
                      ),
                      SizedBox(
                        width: 250,
                        child: HMBDateTimeField(
                          initialDateTime: end.toDateTime(),
                          showDate: false,
                          onChanged: (date) async =>
                              day.end = LocalTime.fromDateTime(date),
                          label: 'End',
                        ),
                      ),
                    ],
                  ),
                  const HMBSpacer(height: true),
                ],
              );
            }),
          ),
        ],
      );

  // OperatingHours createFromUi() {
  //   // 2. Build up an OperatingHours object from local UI state
  //   final selectedDays = <OperatingDay>[];
  //   for (var i = 0; i < _dayOrder.length; i++) {
  //     if (_selectedDays[i]) {
  //       final dayEnum = _dayOrder[i];
  //       final startTod = _startTimes[dayEnum];
  //       final endTod = _endTimes[dayEnum];

  //       // Convert TimeOfDay to "HH:mm" strings
  //       final startStr =
  //           (startTod != null) ? _timeOfDayToString(startTod) : null;
  //       final endStr = (endTod != null) ? _timeOfDayToString(endTod) : null;

  //       selectedDays.add(
  //         OperatingDay(dayName: dayEnum, start: startStr, end: endStr),
  //       );
  //     }
  //   }
  //   return OperatingHours(days: selectedDays);
  // }

  // Utility: convert TimeOfDay to "08:00" string
  String _timeOfDayToString(LocalTime tod) => formatLocalTime(tod);

  // Utility: convert "08:00" to TimeOfDay
  LocalTime _stringToTimeOfDay(String timeStr) => LocalTime.parse(timeStr);
}
