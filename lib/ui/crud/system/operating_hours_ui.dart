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

import 'package:flutter/material.dart';

import '../../../entity/operating_hours.dart';
import '../../../entity/system.dart';
import '../../../util/local_time.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../../widgets/widgets.g.dart';

class OperatingHoursController {
  final OperatingHours operatingHours;
  
  OperatingHoursController({required this.operatingHours});

}

class OperatingHoursUi extends StatefulWidget {
  final OperatingHoursController controller;

  const OperatingHoursUi({required this.controller, super.key});


  @override
  State<OperatingHoursUi> createState() => _OperatingHoursUiState();
}

class _OperatingHoursUiState extends State<OperatingHoursUi> {
  @override
  void initState() {
    super.initState();
  }

  // In a known order for easy indexing
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
  Widget build(BuildContext context) {
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operating Days and Hours',
            style: TextStyle(fontSize: 16),
          ).help(
            'Toggle Open Days',
            'Toggle a day name to indicate on which days you operate. '
                'Then set your start and end times for each day',
          ),
          const SizedBox(height: 8),
          ToggleButtons(
            isSelected: widget.controller.operatingHours.openList,
            onPressed: (index) {
              setState(() {
                final dayName = DayName.fromIndex(index);
                final day = widget.controller.operatingHours.day(dayName);
                day.open = !day.open;
              });
            },
            children: _dayOrder.map((d) => Text(d.shortName)).toList(),
          ),
          const SizedBox(height: 16),
          if (widget.controller.operatingHours.noOpenDays())
            const HMBTextLine(
              'You must set at least one day as Open to use Scheduling!',
              colour: Colors.amber,
            )
          else
            Column(
              children: List.generate(_dayOrder.length, (index) {
                final dayName = DayName.fromIndex(index);
                if (!widget.controller.operatingHours.day(dayName).open) {
                  return const SizedBox.shrink();
                }

                final operatingHours = widget.controller.operatingHours;
                final day = operatingHours.days[DayName.values[index]]!;
                final start =
                    day.start ??
                    LocalTime.fromDateTime(
                      DateTime.now().copyWith(hour: 9, minute: 0),
                    );
                final end =
                    day.end ??
                    LocalTime.fromDateTime(
                      DateTime.now().copyWith(hour: 17, minute: 0),
                    );

                {
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
                            width: 180,
                            child: HMBDateTimeField(
                              initialDateTime: start.toDateTime(),
                              mode: HMBDateTimeFieldMode.timeOnly,
                              onChanged: (date) =>
                                  day.start = LocalTime.fromDateTime(date),
                              label: 'Start',
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: HMBDateTimeField(
                              initialDateTime: end.toDateTime(),
                              mode: HMBDateTimeFieldMode.timeOnly,
                              onChanged: (date) =>
                                  day.end = LocalTime.fromDateTime(date),
                              label: 'End',
                            ),
                          ),
                        ],
                      ),
                      const HMBSpacer(height: true),
                    ],
                  );
                }
              }),
            ),
        ],
      );
    }
  }
}
