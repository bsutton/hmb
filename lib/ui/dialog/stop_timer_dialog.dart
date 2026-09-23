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

import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../entity/task.dart';
import '../../entity/time_entry.dart';
import '../../util/dart/format.dart';
import '../widgets/fields/hmb_text_area.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_date_time_picker.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/text/hmb_text.dart';
import 'hmb_dialog.dart';
import 'long_duration_dialog.dart';

class StopTimerDialog extends StatefulWidget {
  final Task task;
  final TimeEntry timeEntry;
  final bool showTask;
  final DateTime stopTime;

  const StopTimerDialog({
    required this.task,
    required this.showTask,
    required this.timeEntry,
    required this.stopTime,
    super.key,
  });

  @override
  State<StopTimerDialog> createState() => _StopTimerDialogState();

  static Future<TimeEntry?> show(
    BuildContext context, {
    required Task task,
    required TimeEntry timeEntry,
    required DateTime stopTime,
    bool showTask = false,
  }) => showDialog<TimeEntry>(
    context: context,
    builder: (context) => StopTimerDialog(
      task: task,
      showTask: showTask,
      timeEntry: timeEntry,
      stopTime: stopTime,
    ),
  );
}

class _StopTimerDialogState extends State<StopTimerDialog> {
  late DateTime _selectedStop;
  late final TextEditingController _noteController;
  final _noteFocusNode = FocusNode();

  Duration get _duration =>
      _selectedStop.difference(widget.timeEntry.startTime);

  DateTime _atMinute(DateTime value) =>
      DateTime(value.year, value.month, value.day, value.hour, value.minute);

  @override
  void initState() {
    super.initState();
    _selectedStop = _atMinute(widget.stopTime.toLocal());
    final start = widget.timeEntry.startTime.toLocal();
    if (_selectedStop.isBefore(start)) {
      // A handoff can start a task after the rounded current stop time.
      // Suggest the earliest selectable minute that is not before its start.
      final startMinute = _atMinute(start);
      _selectedStop = startMinute.isBefore(start)
          ? startMinute.add(const Duration(minutes: 1))
          : startMinute;
    }
    _noteController = TextEditingController(text: widget.timeEntry.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = _duration;
    final magnitude = duration.abs();
    final formattedDuration = formatDuration(
      magnitude,
      seconds: magnitude > Duration.zero && magnitude.inMinutes == 0,
    );

    return HMBDialog(
      title: const HMBRow(
        children: [
          Icon(Icons.stop, color: Colors.red),
          Text('Stop Timer'),
        ],
      ),
      content: HMBColumn(
        mainAxisSize: MainAxisSize.min,
        children: [
          HMBText('Current Time: ${formatDateTime(DateTime.now())}'),
          if (widget.showTask) buildTaskDetails(),
          Row(
            children: [
              const HMBText('Start:', bold: true),
              const HMBSpacer(width: true),
              HMBText(formatDateTime(widget.timeEntry.startTime)),
            ],
          ),
          HMBDateTimeField(
            label: 'Stop:',
            mode: HMBDateTimeFieldMode.dateAndTime,
            initialDateTime: _selectedStop,
            onChanged: (date) => setState(() {
              _selectedStop = _atMinute(date.toLocal());
            }),
          ),
          HMBText(
            'Duration: ${duration.isNegative ? '-' : ''}$formattedDuration',
          ),
          if (duration.isNegative)
            Text(
              'Stop time must be at or after the start time.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          HMBTextArea(
            controller: _noteController,
            focusNode: _noteFocusNode,
            labelText: 'Note',
          ),
        ],
      ),
      actions: [
        HMBSaveCancelButtons(
          saveLabel: 'Stop timer',
          saveHint: 'Stop this task timer',
          cancelHint: 'Keep the timer running',
          saveEnabled: !duration.isNegative,
          onCancel: () => Navigator.pop(context),
          onSave: () async {
            final duration = _duration;
            if (duration.isNegative) {
              return;
            }
            if (duration.inHours > TimeEntry.longDurationHours) {
              final confirm = await showLongDurationDialog(context, duration);
              if (!confirm) {
                return;
              }
            }

            final timeEntry = widget.timeEntry.copyWith(
              taskId: widget.task.id,
              startTime: widget.timeEntry.startTime,
              endTime: _selectedStop,
              note: _noteController.text,
            );

            if (context.mounted) {
              Navigator.pop(context, timeEntry);
            }
          },
        ),
      ],
    );
  }

  Widget buildTaskDetails() => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FutureBuilderEx(
        future: DaoJob().getById(widget.task.jobId),
        builder: (context, job) => HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilderEx(
              future: DaoCustomer().getById(job!.customerId),
              builder: (context, customer) => HMBColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HMBText('Customer: ${customer!.name}', bold: true),
                  HMBText('Job: ${job.summary}', bold: true),
                ],
              ),
            ),
          ],
        ),
      ),
      HMBText('Task: ${widget.task.name}', bold: true),
      HMBText(widget.task.description),
    ],
  );
}
