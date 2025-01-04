import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_contact.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_job_event.dart';
import '../../dao/dao_job_status.dart';
import '../../entity/contact.dart';
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
  JobEventStatus _status = JobEventStatus.proposed; // Default status
  String? _notes;
  Job? _selectedJob;
  final _form = GlobalKey<FormState>();
  DateTime? _noticeSentDate;

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
      _status = widget.event!.event!.jobEvent.status;
      _notes = widget.event!.event!.jobEvent.notes;
      _noticeSentDate = widget.event!.event!.jobEvent.noticeSentDate;
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

              // Status dropdown
              DropdownButtonFormField<JobEventStatus>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: JobEventStatus.values
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(Strings.toProperCase(status.name)),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _status = value!),
              ),
              const HMBSpacer(height: true),
              // Notes field
              TextFormField(
                initialValue: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
                onChanged: (value) => _notes = value,
              ),
              const HMBSpacer(height: true),
              const HMBSpacer(height: true),
              if (_noticeSentDate != null)
                Text('Notice sent on: ${formatDateTime(_noticeSentDate!)}'),
              const HMBSpacer(height: true),

              // Contact option
              if (widget.isEditing || _selectedJob != null)
                ElevatedButton(
                  onPressed: _showContactOptions,
                  child: const Text('Send Notice'),
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

  /// If the user taps “Delete,” we pop null
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

    // Check for overlapping events
    final overlappingEvent = await _checkForOverlappingEvents();
    if (overlappingEvent != null) {
      if (!mounted) {
        return; // Check if the widget is still in the tree
      }

      final shouldOverride = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Event Overlap'),
          content: Text(
            'This event overlaps with another event: ${overlappingEvent.job.summary} '
            '(${formatDateTime(overlappingEvent.jobEvent.start)} - ${formatDateTime(overlappingEvent.jobEvent.end)}). '
            'Do you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (!(shouldOverride ?? false)) {
        return; // User chose not to override
      }
    }

    _form.currentState?.save();

    late JobEvent jobEvent;
    if (widget.isEditing) {
      jobEvent = widget.event!.event!.jobEvent.copyWith(
        jobId: _selectedJob!.id,
        start: _startDate,
        end: _endDate,
        status: _status,
        notes: _notes,
        noticeSentDate: _noticeSentDate,
      );
    } else {
      /// new job event.
      jobEvent = JobEvent.forInsert(
        jobId: _selectedJob!.id,
        start: _startDate,
        end: _endDate,
        status: _status,
        notes: _notes,
        noticeSentDate: _noticeSentDate,
      );
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

  Future<JobEventEx?> _checkForOverlappingEvents() async {
    final jobEvents = await DaoJobEvent().getByJob(_selectedJob!.id);
    for (final event in jobEvents) {
      if ((_startDate.isBefore(event.end) && _startDate.isAfter(event.start)) ||
          (_endDate.isAfter(event.start) && _endDate.isBefore(event.end)) ||
          (_startDate.isBefore(event.start) && _endDate.isAfter(event.end))) {
        // Exclude the current event being edited from overlap check
        if (!widget.isEditing || event.id != widget.event?.event?.jobEvent.id) {
          return JobEventEx.fromEvent(event);
        }
      }
    }
    return null;
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

  Future<void> _showContactOptions() async {
    // Fetch customer contacts
    final contacts = await _getCustomerContacts();

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Contact Method'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: Icon(
                    contact.method == ContactMethod.email
                        ? Icons.email
                        : Icons.message,
                    color: contact.isPrimary ? Colors.blue : null),
                title: Text(
                  contact.detail,
                  style: TextStyle(
                      fontWeight: contact.isPrimary
                          ? FontWeight.bold
                          : FontWeight.normal),
                ),
                subtitle: Text(
                    '${contact.contact.firstName} ${contact.contact.surname}'),
                onTap: () {
                  Navigator.of(context).pop();
                  _sendNotice(contact);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<List<ContactOption>> _getCustomerContacts() async {
    // final job = await DaoJob().getById(_selectedJob!.id);
    final contactId = _selectedJob?.contactId;
    if (contactId != null) {
      final contactOptions = <ContactOption>[];

      final contact = await DaoContact().getById(contactId);

      // Add job contacts (SMS)
      if (contact != null) {
        // contactOptions.add(ContactOption(
        //   contact: contact,
        //   detail: _selectedJob!.primaryContact,
        //   method: ContactMethod.sms,
        //   isPrimary: true,
        // ));

        // if (_selectedJob!.secondaryContact.isNotEmpty) {
        //   contactOptions.add(ContactOption(
        //     contact: customer,
        //     detail: _selectedJob!.secondaryContact,
        //     method: ContactMethod.sms,
        //   ));
        // }

        // Add customer contacts (Email, SMS)
        if (contact.emailAddress.isNotEmpty) {
          contactOptions.add(ContactOption(
            contact: contact,
            detail: contact.emailAddress,
            method: ContactMethod.email,
          ));
        }
        if (contact.mobileNumber.isNotEmpty) {
          contactOptions.add(ContactOption(
            contact: contact,
            detail: contact.mobileNumber,
            method: ContactMethod.sms,
          ));
        }
      }

      return contactOptions;
    }
    return [];
  }

  void _sendNotice(ContactOption contact) {
    // Implement your logic to send the notice via email or SMS
    // You can use the contact.method and contact.detail to determine how to send the notice

    // For demonstration purposes, we just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Notice sent to ${contact.contact.firstName} via ${contact.method.name} (${contact.detail})')),
    );

    // Record the date the notice was sent
    setState(() {
      _noticeSentDate = DateTime.now();
    });
  }
}

class ContactOption {
  ContactOption({
    required this.contact,
    required this.detail,
    required this.method,
    this.isPrimary = false,
  });

  final Contact contact;
  final String detail;
  final ContactMethod method;
  final bool isPrimary;
}

enum ContactMethod { email, sms }
