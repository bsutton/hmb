// job_event_dialog.dart
import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';

import '../../dao/dao_job.dart';
import '../../entity/job.dart';
import '../../entity/job_event.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_date_time_picker.dart';
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/select/hmb_droplist.dart';
import 'schedule_page.dart';

/// The dialog for adding/editing job events
class JobEventDialog extends StatefulWidget {
  JobEventDialog.edit({
    required CalendarEventData<JobEventEx> this.event,
    super.key,
  })  : when = event.date,
        isEditing = true;

  const JobEventDialog.add({
    required this.when,
    super.key,
  })  : event = null,
        isEditing = false;

  final CalendarEventData<JobEventEx>? event;
  final DateTime? when;
  final bool isEditing;

  @override
  _JobEventDialogState createState() => _JobEventDialogState();

  static Future<JobEventEx?> showAdd({
    required BuildContext context,
    required DateTime when,
  }) =>
      showDialog<JobEventEx>(
        context: context,
        builder: (context) => Material(child: JobEventDialog.add(when: when)),
      );

  static Future<JobEventEx?> showEdit(
    BuildContext context,
    CalendarEventData<JobEventEx> event,
  ) =>
      showDialog<JobEventEx>(
        context: context,
        builder: (context) =>
            Material(child: JobEventDialog.edit(event: event)),
      );
}

class _JobEventDialogState extends State<JobEventDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  Job? _selectedJob;
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    if (widget.event == null) {
      // Adding a new event
      _startDate = widget.when!;
      _endDate = widget.when!.add(const Duration(hours: 4));
    } else {
      // Editing an existing event
      _startDate = widget.event!.startTime ?? DateTime.now();
      _endDate = widget.event!.endTime ?? DateTime.now();
      _selectedJob = widget.event?.event!.job;
    }
  }

  @override
  @override
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen =
        screenWidth < 600; // Define threshold for small screens

    // Calculate the duration
    final duration = _endDate.difference(_startDate);

    return Form(
      key: _form,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (isSmallScreen) ...[
                // Vertical layout for small screens
                _buildStartDate(),
                const SizedBox(height: 15),
                _buildEndDate(context),
                const SizedBox(height: 15),
              ] else ...[
                // Horizontal layout for larger screens
                Row(
                  children: [
                    Expanded(
                      child: _buildStartDate(),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildEndDate(context),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
              ],
              // Display the duration
              Row(
                children: [
                  Text(
                    'Duration: ${_formatDuration(duration)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  HMBButtonSecondary(
                    onPressed: () => Navigator.of(context).pop(),
                    label: 'Cancel',
                  ),
                  const HMBSpacer(width: true),
                  if (widget.isEditing) ...[
                    HMBButtonSecondary(
                      onPressed: _handleDelete,
                      label: 'Delete',
                    ),
                    const HMBSpacer(width: true),
                  ],
                  HMBButtonPrimary(
                    onPressed: _handleSave,
                    label: widget.isEditing ? 'Update Event' : 'Add Event',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper to format the duration
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  /// End Date
  HMBDateTimeField _buildEndDate(BuildContext context) => HMBDateTimeField(
        showDate: false,
        label: 'End Date',
        initialDateTime: _endDate,
        onChanged: (date) {
          if (date.isBefore(_startDate)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('End date occurs before start date.'),
              ),
            );
            return;
          }
          setState(() => _endDate = date);
        },
      );

  /// Start Date
  HMBDateTimeField _buildStartDate() => HMBDateTimeField(
        showDate: false,
        label: 'Start Date',
        initialDateTime: _startDate,
        onChanged: (date) {
          if (date.isAfter(_endDate)) {
            _endDate = date.add(const Duration(hours: 1));
          }
          setState(() => _startDate = date);
        },
      );

  /// If the user taps “Delete,” we pop `null`
  /// to indicate a delete request.
  void _handleDelete() {
    Navigator.of(context).pop();
  }

  Future<void> _handleSave() async {
    if (!(_form.currentState?.validate() ?? true)) {
      return;
    }

    if (_selectedJob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a job for the event.')),
      );
      return;
    }

    _form.currentState?.save();

    late JobEvent jobEvent;
    if (widget.isEditing) {
      jobEvent = widget.event!.event!.jobEvent.copyWith(
        jobId: _selectedJob!.id,
        startDate: _startDate,
        endDate: _endDate,
      );
    } else {
      /// new job event.
      jobEvent = JobEvent.forInsert(
          jobId: _selectedJob!.id, startDate: _startDate, endDate: _endDate);
    }
    final jobEventEx = await JobEventEx.fromEvent(jobEvent);

    if (mounted) {
      Navigator.of(context).pop(jobEventEx);
    }
  }
}
