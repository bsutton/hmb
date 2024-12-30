import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';

import '../../dao/dao_job.dart';
import '../../entity/job.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_date_time_picker.dart';
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/select/hmb_droplist.dart';
import 'schedule_page.dart';

class JobEventDialog extends StatefulWidget {
  JobEventDialog({
    required CalendarEventData<JobEvent> this.event,
    super.key,
  }) : when = event.date;

  const JobEventDialog.add({required this.when, super.key}) : event = null;

  // fields
  final CalendarEventData<JobEvent>? event;
  final DateTime? when;

  @override
  _JobEventDialogState createState() => _JobEventDialogState();

  static Future<JobEvent?> showAdd(
          {required BuildContext context, required DateTime when}) =>
      showDialog<JobEvent>(
          context: context,
          builder: (context) =>
              Material(child: JobEventDialog.add(when: when)));

  static Future<JobEvent?> showEdit(
          BuildContext context, CalendarEventData<JobEvent> event) =>
      showDialog<JobEvent>(
          context: context,
          builder: (context) => Material(child: JobEventDialog(event: event)));
}

class _JobEventDialogState extends State<JobEventDialog> {
  late DateTime _startDate;
  late DateTime _endDate;

  Job? _selectedJob;
  final _form = GlobalKey<FormState>();

  late final _titleNode = FocusNode();
  late final _descriptionNode = FocusNode();

  @override
  void initState() {
    super.initState();

    if (widget.event == null) {
      _startDate = widget.when!;
      _endDate = widget.when!.add(const Duration(hours: 4));
    } else {
      _startDate = widget.event!.startTime ?? DateTime.now();
      _endDate = widget.event!.endTime ?? DateTime.now();
      _selectedJob = widget.event?.event!.job;
    }
  }

  @override
  void dispose() {
    _titleNode.dispose();
    _descriptionNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 15),
            HMBDroplist<Job>(
              selectedItem: () async => _selectedJob,
              items: (filter) async => DaoJob().getActiveJobs(filter),
              format: (job) => job.summary,
              onChanged: (job) => setState(() {
                _selectedJob = job;
              }),
              title: 'Select Job',
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: HMBDateTimeField(
                    showDate: false,
                    label: 'Start Date',
                    initialDateTime: _startDate,
                    onChanged: (date) {
                      // If new start date is after the current end date, shift end date
                      if (date.isAfter(_endDate)) {
                        _endDate = date.add(const Duration(hours: 1));
                      }
                      _startDate = date;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: HMBDateTimeField(
                    showDate: false,
                    initialDateTime: _endDate,
                    label: 'End Date',
                    onChanged: (date) {
                      if (date.isBefore(_startDate)) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('End date occurs before start date.'),
                        ));
                      } else {
                        _endDate = date;
                      }
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HMBButtonPrimary(
                  onPressed: () => Navigator.of(context).pop(),
                  label: 'Cancel',
                ),
                const HMBSpacer(width: true),
                HMBButtonPrimary(
                  onPressed: _createEvent,
                  label: widget.event == null ? 'Add Event' : 'Update Event',
                ),
              ],
            ),
          ],
        ),
      );

  void _createEvent() {
    // If form or required fields fail validation, do nothing.
    if (!(_form.currentState?.validate() ?? true)) return;

    // If no job is selected, ask the user to pick one.
    if (_selectedJob == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a job for the event.'),
      ));
      return;
    }

    _form.currentState?.save();

    // Create a new JobEvent object with the selected job and date range
    final jobEvent =
        JobEvent(job: _selectedJob!, start: _startDate, end: _endDate);

    // Return this event back to the caller
    Navigator.of(context).pop(jobEvent);
  }
}
