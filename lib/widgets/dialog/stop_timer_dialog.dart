import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../entity/task.dart';
import '../../entity/time_entry.dart';
import '../../util/format.dart';
import '../fields/hmb_text_area.dart';
import '../hmb_date_time_picker.dart';
import '../hmb_toast.dart';
import '../layout/hmb_spacer.dart';
import '../text/hmb_text.dart';
import 'hmb_dialog.dart';

class StopTimerDialog extends StatefulWidget {
  const StopTimerDialog({
    required this.task,
    required this.showTask,
    required this.timeEntry,
    required this.stopTime,
    super.key,
  });

  final Task task;
  final TimeEntry timeEntry;
  final bool showTask;
  final DateTime stopTime;

  @override
  State<StopTimerDialog> createState() => _StopTimerDialogState();

  static Future<TimeEntry?> show(BuildContext context,
          {required Task task,
          required TimeEntry timeEntry,
          required DateTime stopTime,
          bool showTask = false}) =>
      showDialog<TimeEntry>(
        context: context,
        builder: (context) => StopTimerDialog(
            task: task,
            showTask: showTask,
            timeEntry: timeEntry,
            stopTime: stopTime),
      );
}

class _StopTimerDialogState extends State<StopTimerDialog> {
  late DateTime selectedDate;
  late TimeOfDay selectedTime;
  late Duration duration;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.stopTime;
    selectedTime = TimeOfDay.fromDateTime(widget.stopTime);
    duration = selectedDate.difference(widget.timeEntry.startTime);
  }

  void _updateDuration() {
    final stopDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    setState(() {
      duration = stopDateTime.difference(widget.timeEntry.startTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    final noteController = TextEditingController();
    final noteFocusNode = FocusNode();

    noteController.text = widget.timeEntry.note ?? '';

    return HMBDialog(
      title: const Row(
        children: [
          Icon(Icons.stop, color: Colors.red),
          SizedBox(width: 8),
          Text('Stop Timer'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HMBText('Current Time: ${formatDateTime(DateTime.now())}'),
          if (widget.showTask) buildTaskDetails(),
          Row(children: [
            HMBText(
              'Start:',
              bold: true,
            ),
            const HMBSpacer(width: true),
            HMBText(formatDateTime(widget.timeEntry.startTime))
          ]),
          HMBDateTimeField(
            label: 'Stop:',
            initialDateTime: selectedDate,
            onChanged: (date) {
              setState(() {
                selectedDate = date;
                selectedTime = TimeOfDay.fromDateTime(date);
              });
              _updateDuration();
            },
          ),
          HMBText('Duration: ${duration.inHours}h ${duration.inMinutes % 60}m'),
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
          onPressed: () async {
            final stopDateTime = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );

            if (duration.isNegative) {
              HMBToast.error('The duration is negative');
              return;
            }
            if (duration.inHours > 8) {
              final confirm = await _showLongDurationDialog(context, duration);
              if (!confirm) {
                return;
              }
            }

            final note = noteController.text;
            final timeEntry = TimeEntry.forUpdate(
                entity: widget.timeEntry,
                taskId: widget.task.id,
                startTime: widget.timeEntry.startTime,
                endTime: stopDateTime,
                note: note);

            if (context.mounted) {
              Navigator.pop(context, timeEntry);
            }
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  Future<bool> _showLongDurationDialog(
          BuildContext context, Duration duration) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => HMBDialog(
          title: const Text('Long Duration Warning'),
          content: Text(
              '''The time entry duration is ${duration.inHours} hours. Do you want to continue?'''),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  Widget buildTaskDetails() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoJob().getById(widget.task.jobId),
              builder: (context, job) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilderEx(
                          // ignore: discarded_futures
                          future: DaoCustomer().getById(job!.customerId),
                          builder: (context, customer) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  HMBText('Customer: ${customer!.name}',
                                      bold: true),
                                  HMBText('Job: ${job.summary}', bold: true),
                                ],
                              )),
                    ],
                  )),
          const SizedBox(height: 8),
          HMBText('Task: ${widget.task.name}', bold: true),
          HMBText(widget.task.description),
        ],
      );
}
