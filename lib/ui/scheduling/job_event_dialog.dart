// job_event_dialog.dart
import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';

import '../../dao/dao_job.dart';
import '../../dao/dao_job_status.dart';
import '../../entity/job.dart';
import '../../entity/job_event.dart';
import '../../util/format.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_date_time_picker.dart';
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/select/hmb_droplist.dart';
import 'job_event_ex.dart';

class JobEventUpdateAction {
  JobEventUpdateAction(this.action, this.jobEvent);
  JobEventEx? jobEvent;
  EditAction action;
}

class JobEventAddAction {
  JobEventAddAction(this.action, this.jobEvent);
  JobEventEx? jobEvent;
  AddAction action;
}

enum EditAction { delete, update, cancel }

enum AddAction { add, cancel }

/// The dialog for adding/editing job events
class JobEventDialog extends StatefulWidget {
  JobEventDialog.edit({
    required CalendarEventData<JobEventEx> this.event,
    this.preSelectedJobId,
    super.key,
  })  : when = event.date,
        isEditing = true;

  const JobEventDialog.add({
    required this.when,
    this.preSelectedJobId,
    super.key,
  })  : event = null,
        isEditing = false;

  final int? preSelectedJobId;
  final CalendarEventData<JobEventEx>? event;
  final DateTime? when;
  final bool isEditing;

  @override
  _JobEventDialogState createState() => _JobEventDialogState();

  static Future<JobEventAddAction?> showAdd({
    required BuildContext context,
    required DateTime when,
    required int? defaultJob,
  }) =>
      showDialog<JobEventAddAction>(
        context: context,
        builder: (context) => Material(
          child: JobEventDialog.add(
            when: when,
            preSelectedJobId: defaultJob,
          ),
        ),
      );

  static Future<JobEventUpdateAction?> showEdit(
    BuildContext context,
    CalendarEventData<JobEventEx> event,
  ) =>
      showDialog<JobEventUpdateAction>(
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
      // If we have a preSelectedJobId, fetch that job from DB
      if (widget.preSelectedJobId != null) {
        // ignore: discarded_futures
        DaoJob().getById(widget.preSelectedJobId).then((job) {
          if (mounted && job != null) {
            setState(() {
              _selectedJob = job;
            });
          }
        });
      }

      // default times
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
              const HMBSpacer(height: true),
              // Display event date
              Text(
                'Event Date: ${formatDate(_startDate)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const HMBSpacer(height: true),
              if (isSmallScreen) ...[
                // Vertical layout for small screens
                _buildStartDate(),
                const HMBSpacer(height: true),
                _buildEndDate(context),
                const HMBSpacer(height: true),
              ] else ...[
                // Horizontal layout for larger screens
                Row(
                  children: [
                    Expanded(
                      child: _buildStartDate(),
                    ),
                    const HMBSpacer(height: true),
                    Expanded(
                      child: _buildEndDate(context),
                    ),
                  ],
                ),
                const HMBSpacer(height: true),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Delete button on the left
                  if (widget.isEditing)
                    HMBButtonSecondary(
                      onPressed: _handleDelete,
                      label: 'Delete',
                    )
                  else
                    const SizedBox(), // Placeholder for alignment when not editing

                  // Cancel and Save buttons on the right
                  Row(
                    children: [
                      HMBButtonSecondary(
                        onPressed: () => Navigator.of(context).pop(
                            widget.isEditing
                                ? JobEventUpdateAction(EditAction.cancel, null)
                                : JobEventAddAction(AddAction.cancel, null)),
                        label: 'Cancel',
                      ),
                      const HMBSpacer(width: true),
                      HMBButtonPrimary(
                        onPressed: _handleSave,
                        label: widget.isEditing ? 'Update Event' : 'Add Event',
                      ),
                    ],
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
    Navigator.of(context)
        .pop(JobEventUpdateAction(EditAction.delete, widget.event!.event));
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
        start: _startDate,
        end: _endDate,
      );
    } else {
      /// new job event.
      jobEvent = JobEvent.forInsert(
          jobId: _selectedJob!.id, start: _startDate, end: _endDate);
    }
    final jobEventEx = await JobEventEx.fromEvent(jobEvent);

    await _updateJobStatus();

    if (mounted) {
      if (widget.isEditing) {
        Navigator.of(context)
            .pop(JobEventUpdateAction(EditAction.update, jobEventEx));
      } else {
        Navigator.of(context).pop(JobEventAddAction(AddAction.add, jobEventEx));
      }
    }
  }

  Future<void> _updateJobStatus() async {
    // Next, check the job’s status
    final job = await DaoJob().getById(_selectedJob!.id);
    if (job != null) {
      final jobStatus = await DaoJobStatus().getById(job.jobStatusId);
      if (jobStatus != null) {
        final statusesThatShouldBecomeScheduled = [
          'prospecting',
          'quoting',
          'awaiting approval',
          'to be scheduled',
          'on hold'
        ];

        // Convert the jobStatus name or statusEnum to lower, compare
        final currentStatus = jobStatus.name.toLowerCase();
        if (statusesThatShouldBecomeScheduled.contains(currentStatus)) {
          // fetch the “Scheduled” status
          final scheduledStatus = await DaoJobStatus().getByName('Scheduled');
          if (scheduledStatus != null) {
            job.jobStatusId = scheduledStatus.id;
            await DaoJob().update(job);
          }
        }
      }
    }
  }
}
