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
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../entity/task.dart';
import '../../entity/time_entry.dart';
import '../../ui/widgets/hmb_date_time_picker.dart';
import '../../ui/widgets/hmb_toast.dart';
import '../../util/format.dart';
import '../widgets/fields/hmb_text_area.dart';
import '../widgets/hmb_button.dart';
import '../widgets/text/hmb_text.dart';
import 'hmb_dialog.dart';

class StartTimerDialog extends StatefulWidget {
  final Task task;
  final bool showTask;
  final DateTime startTime;

  const StartTimerDialog({
    required this.task,
    required this.showTask,
    required this.startTime,
    super.key,
  });

  @override
  State<StartTimerDialog> createState() => _StartTimerDialogState();

  static Future<TimeEntry?> show(
    BuildContext context, {
    required Task task,
    required DateTime startTime,
    bool showTask = false,
  }) => showDialog<TimeEntry>(
    context: context,
    builder: (context) =>
        StartTimerDialog(task: task, showTask: showTask, startTime: startTime),
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
            mode: HMBDateTimeFieldMode.dateAndTime,
            label: 'Time:',
            initialDateTime: selected,
            onChanged: (dateTime) => selected = dateTime,
          ),
          HMBTextArea(
            controller: noteController,
            focusNode: noteFocusNode,
            labelText: 'Note',
          ),
        ],
      ),
      actions: [
        HMBButton(
          label: 'Cancel',
          hint: "Don't start the timer",
          onPressed: () => Navigator.pop(context),
        ),
        HMBButton(
          label: 'OK',
          hint: 'Start the timer',
          onPressed: () {
            final note = noteController.text;
            TimeEntry timeEntry;

            /// start time must be in the past or within the next
            /// fifteen minutes.
            if (selected.isAfter(
              DateTime.now().add(const Duration(minutes: 15)),
            )) {
              HMBToast.error(
                'Start Time must be in the past or within 15min of now.',
              );
              return;
            }
            timeEntry = TimeEntry.forInsert(
              taskId: widget.task.id,
              startTime: selected,
              note: note,
            );
            Navigator.pop(context, timeEntry);
          },
        ),
      ],
    );
  }

  Widget buildTaskDetails() => Column(
    children: [
      FutureBuilderEx(
        // ignore: discarded_futures
        future: DaoJob().getById(widget.task.jobId),
        builder: (context, job) => Column(
          children: [
            FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoCustomer().getById(job!.customerId),
              builder: (context, customer) =>
                  Column(children: [Text(customer!.name), Text(job.summary)]),
            ),
          ],
        ),
      ),
      Text(widget.task.description),
    ],
  );
}
