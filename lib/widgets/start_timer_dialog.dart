import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../dao/dao_customer.dart';
import '../dao/dao_job.dart';
import '../entity/task.dart';
import '../entity/time_entry.dart';
import '../util/format.dart';
import 'hmb_date_time_picker.dart';
import 'hmb_dialog.dart';
import 'hmb_text.dart';
import 'hmb_text_area.dart';
import 'hmb_toast.dart';

class StartTimerDialog extends StatefulWidget {
  const StartTimerDialog(
      {required this.task,
      required this.showTask,
      required this.startTime,
      super.key});
  final Task task;
  final bool showTask;
  final DateTime startTime;

  @override
  State<StartTimerDialog> createState() => _StartTimerDialogState();

  static Future<TimeEntry?> show(BuildContext context,
          {required Task task,
          required DateTime startTime,
          bool showTask = false}) =>
      showDialog<TimeEntry>(
        context: context,
        builder: (context) => StartTimerDialog(
            task: task, showTask: showTask, startTime: startTime),
      );
}

class _StartTimerDialogState extends State<StartTimerDialog> {
  late DateTime selected;

  @override
  void initState() {
    super.initState();
    selected = widget.startTime;
  }

  @override
  Widget build(BuildContext context) {
    final noteController = TextEditingController();
    final noteFocusNode = FocusNode();

    noteController.text = '';

    return HMBDialog(
      title: const Text('Start Timer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HMBText('Current Time: ${formatDateTime(DateTime.now())}'),
          if (widget.showTask) buildTaskDetails(),
          HMBDateTimeField(
              label: 'Time:',
              initialDateTime: selected,
              onChanged: (dateTime) => selected = dateTime),
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
            final note = noteController.text;
            TimeEntry timeEntry;

            /// start time must be in the past or within the next
            /// fifteen minutes.
            if (selected
                .isAfter(DateTime.now().add(const Duration(minutes: 15)))) {
              HMBToast.error(
                  'Start Time must be in the past or within 15min of now.');
              return;
            }
            timeEntry = TimeEntry.forInsert(
                taskId: widget.task.id, startTime: selected, note: note);
            Navigator.pop(context, timeEntry);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

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
