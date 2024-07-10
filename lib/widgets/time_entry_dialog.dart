import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../dao/dao_customer.dart';
import '../dao/dao_job.dart';
import '../entity/task.dart';
import '../entity/time_entry.dart';
import '../util/format.dart';
import 'hmb_date_time_picker.dart';
import 'hmb_text.dart';
import 'hmb_text_area.dart';
import 'hmb_toast.dart';

// final _dateTimeFormat = DateFormat('yyyy-MM-dd hh:mm a');

class TimeEntryDialog extends StatefulWidget {
  const TimeEntryDialog(
      {required this.task,
      required this.showTask,
      super.key,
      this.openEntry,
      this.followOnStartTime});
  final Task task;
  final TimeEntry? openEntry;
  final bool showTask;
  final DateTime? followOnStartTime;

  @override
  State<TimeEntryDialog> createState() => _TimeEntryDialogState();
}

class _TimeEntryDialogState extends State<TimeEntryDialog> {
  DateTime? selected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    DateTime nearestQuarterHour;

    if (widget.openEntry == null) {
      /// start time
      nearestQuarterHour = widget.followOnStartTime ??
          DateTime(
              now.year, now.month, now.day, now.hour, (now.minute ~/ 15) * 15);
    } else {
      // end time
      nearestQuarterHour = DateTime(now.year, now.month, now.day, now.hour,
          ((now.minute ~/ 15) + 1) * 15);
    }
    // If the user doesn't change the value then [selected]
    // needs to reflect the starting value.
    selected = nearestQuarterHour;

    // final dateTimeController = TextEditingController(
    //   text: formatDateTime(nearestQuarterHour),
    // );
    final noteController = TextEditingController();
    // final dateTimeFocusNode = FocusNode();
    final noteFocusNode = FocusNode();

    noteController.text = widget.openEntry?.note ?? '';

    return AlertDialog(
      title: Text(widget.openEntry != null ? 'Stop Timer' : 'Start Timer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HMBText('Current Time: ${formatDateTime(DateTime.now())}'),

          if (widget.showTask == true) buildTaskDetails(),
          if (widget.openEntry != null)
            HMBText('Start: ${formatDateTime(widget.openEntry!.startTime)}'),
          HMBDateTimeField(
              initialDateTime: nearestQuarterHour,
              onChanged: (dateTime) => selected = dateTime),
          // GestureDetector(
          //   onTap: () async => _selectDateTime(context, dateTimeController),
          //   child: AbsorbPointer(
          //     child: HMBTextField(
          //       controller: dateTimeController,
          //       focusNode: dateTimeFocusNode,
          //       labelText: openEntry != null ? 'Stop Timer' : 'Start Timer',
          //       keyboardType: TextInputType.datetime,
          //       required: true,
          //     ),
          //   ),
          // ),
          HMBTextArea(
            controller: noteController,
            focusNode: noteFocusNode,
            labelText: 'Note',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // final selectedDateTime = parseDateTime(dateTimeController.text);
            final note = noteController.text;
            TimeEntry timeEntry;
            if (widget.openEntry == null) {
              /// start time must be in the past or within the next
              /// fifteen minutes.
              if (selected!
                  .isAfter(DateTime.now().add(const Duration(minutes: 15)))) {
                HMBToast.error(
                    'Start Time must be in the past or within 15min of now.');
                return;
              }
              timeEntry = TimeEntry.forInsert(
                  taskId: widget.task.id, startTime: selected!, note: note);
            } else {
              timeEntry = TimeEntry.forUpdate(
                  entity: widget.openEntry!,
                  taskId: widget.task.id,
                  startTime: widget.openEntry!.startTime,
                  endTime: selected,
                  note: note);
            }
            Navigator.pop(context, timeEntry);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  // Future<void> _selectDateTime(
  //     BuildContext context, TextEditingController controller) async {
  //   final selectedDate = await showDatePicker(
  //     context: context,
  //     initialDate: DateTime.now(),
  //     firstDate: DateTime(2000),
  //     lastDate: DateTime(2101),
  //   );

  //   if (selectedDate != null && context.mounted) {
  //     final selectedTime = await showTimePicker(
  //       context: context,
  //       initialTime: TimeOfDay.now(),
  //       builder: (context, child) => MediaQuery(
  //         data: MediaQuery.of(context)
  //            .copyWith(alwaysUse24HourFormat: false),
  //         child: child!,
  //       ),
  //     );

  //     if (selectedTime != null) {
  //       final finalDateTime = DateTime(
  //         selectedDate.year,
  //         selectedDate.month,
  //         selectedDate.day,
  //         selectedTime.hour,
  //         selectedTime.minute,
  //       );
  //       controller.text = formatDateTime(finalDateTime);
  //     }
  //   }
  // }

  Widget buildTaskDetails() => Column(children: [
        FutureBuilderEx(
            // ignore: discarded_futures
            future: DaoJob().getById(widget.task.jobId),
            builder: (context, job) => Column(
                  children: [
                    FutureBuilderEx(
                        // ignore: discarded_futures
                        future: DaoCustomer().getById(job!.customerId),
                        builder: (context, customer) => Column(
                              children: [
                                Text(customer!.name),
                                Text(job.summary),
                              ],
                            )),
                  ],
                )),
        Text(widget.task.description)
      ]);
}
