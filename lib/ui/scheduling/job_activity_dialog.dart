import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_contact.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_job_activity.dart';
import '../../dao/dao_job_status.dart';
import '../../entity/contact.dart';
import '../../entity/job.dart';
import '../../entity/job_activity.dart';
import '../../util/date_time_ex.dart';
import '../../util/format.dart';
import '../../util/local_date.dart';
import '../../util/local_time.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_date_time_picker.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/layout/hmb_scroll_for_keyboard.dart';
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/select/hmb_droplist.dart';
import 'job_activity_ex.dart';

class JobActivityUpdateAction {
  JobActivityUpdateAction(this.action, this.jobActivity);
  JobActivityEx? jobActivity;
  EditAction action;
}

class JobActivityAddAction {
  JobActivityAddAction(this.action, this.jobActivity);
  JobActivityEx? jobActivity;
  AddAction action;
}

enum EditAction { delete, update, cancel }

enum AddAction { add, cancel }

/// The dialog for adding/editing job events
class JobActivityDialog extends StatefulWidget {
  JobActivityDialog.edit({
    required CalendarEventData<JobActivityEx> this.event,
    this.preSelectedJobId,
    super.key,
  }) : when = event.date,
       isEditing = true;

  const JobActivityDialog.add({
    required this.when,
    this.preSelectedJobId,
    super.key,
  }) : event = null,
       isEditing = false;

  final int? preSelectedJobId;
  final CalendarEventData<JobActivityEx>? event;
  final DateTime? when;
  final bool isEditing;

  static Future<JobActivityAddAction> showAdd({
    required BuildContext context,
    required DateTime when,
    required int? defaultJob,
  }) async {
    var result = await showDialog<JobActivityAddAction>(
      context: context,
      builder: (context) => Material(
        child: JobActivityDialog.add(when: when, preSelectedJobId: defaultJob),
      ),
    );
    return result ??= JobActivityAddAction(AddAction.cancel, null);
  }

  static Future<JobActivityUpdateAction> showEdit(
    BuildContext context,
    CalendarEventData<JobActivityEx> event,
  ) async {
    var result = await showDialog<JobActivityUpdateAction>(
      context: context,
      builder: (context) =>
          Material(child: JobActivityDialog.edit(event: event)),
    );
    return result ??= JobActivityUpdateAction(EditAction.cancel, null);
  }

  @override
  _JobActivityDialogState createState() => _JobActivityDialogState();
}

class _JobActivityDialogState extends State<JobActivityDialog> {
  late LocalDate _eventDate;
  late LocalTime _startTime;
  late LocalTime _endTime;

  JobActivityStatus _status = JobActivityStatus.tentative; // Default status
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
      _eventDate = widget.when!.toLocalDate();
      _startTime = widget.when!.toLocalTime();
      _endTime = _startTime.addDuration(const Duration(hours: 4));
    } else {
      // Editing an existing event
      _eventDate = (widget.event!.startTime ?? DateTime.now()).toLocalDate();
      _startTime = (widget.event!.startTime ?? DateTime.now()).toLocalTime();
      _endTime = (widget.event!.endTime ?? DateTime.now()).toLocalTime();
      _selectedJob = widget.event?.event!.job;
      _status = widget.event!.event!.jobActivity.status;
      _notes = widget.event!.event!.jobActivity.notes;
      _noticeSentDate = widget.event!.event!.jobActivity.noticeSentDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen =
        screenWidth < 600; // Define threshold for small screens

    // Calculate the duration
    final duration = _endTime.difference(_startTime);

    return Form(
      key: _form,
      child: HMBScrollForKeyboard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 15),
              HMBDroplist<Job>(
                selectedItem: () async => _selectedJob,
                // ignore: discarded_futures
                items: (filter) => DaoJob().getActiveJobs(filter),
                format: (job) => job.summary,
                onChanged: (job) => setState(() {
                  _selectedJob = job;
                }),
                title: 'Select Job',
              ),
              const HMBSpacer(height: true),
              // Display event date
              _buildEventDate(context),

              const HMBSpacer(height: true),
              ..._buildStartEndDates(isSmallScreen),
              // Display the duration
              _buildDuration(duration),
              // Status dropdown
              _buildStatus(),
              const HMBSpacer(height: true),
              // Notes field
              _buildNotes(),
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
              _buildButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _buildNotes() => TextFormField(
    initialValue: _notes,
    decoration: const InputDecoration(labelText: 'Notes'),
    maxLines: 3,
    onChanged: (value) => _notes = value,
  );

  DropdownButtonFormField<JobActivityStatus> _buildStatus() =>
      DropdownButtonFormField<JobActivityStatus>(
        value: _status,
        decoration: const InputDecoration(labelText: 'Status'),
        items: JobActivityStatus.values
            .map(
              (status) => DropdownMenuItem(
                value: status,
                child: Row(
                  children: [
                    // Colored circle
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: status.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8), // Spacing
                    // Text
                    Text(Strings.toProperCase(status.name)),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _status = value!),
      );

  Row _buildDuration(Duration duration) => Row(
    children: [
      Text(
        'Duration: ${_formatDuration(duration)}',
        style: const TextStyle(fontSize: 16),
      ),
    ],
  );

  Row _buildButtons(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Delete button on the left
      if (widget.isEditing)
        HMBButtonSecondary(onPressed: _handleDelete, label: 'Delete')
      else
        const SizedBox(), // Placeholder for alignment when not editing
      // Cancel and Save buttons on the right
      Row(
        children: [
          HMBButtonSecondary(
            onPressed: () => Navigator.of(context).pop(
              widget.isEditing
                  ? JobActivityUpdateAction(EditAction.cancel, null)
                  : JobActivityAddAction(AddAction.cancel, null),
            ),
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
  );

  /// Helper to format the duration
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  HMBDateTimeField _buildEventDate(BuildContext context) => HMBDateTimeField(
    mode: HMBDateTimeFieldMode.dateOnly,
    label: 'Event Date',
    initialDateTime: _eventDate.toDateTime(),
    width: 200,
    onChanged: (date) {
      setState(() {
        _eventDate = date.toLocalDate();
      });
    },
    validator: (date) {
      if (date == null) {
        return 'You must select a Start Date';
      }
      return null;
    },
  );

  /// End Date
  HMBDateTimeField _buildEndDate(BuildContext context) => HMBDateTimeField(
    mode: HMBDateTimeFieldMode.timeOnly,
    label: 'End Time',
    initialDateTime: _endTime.toDateTime(),
    width: 200,
    onChanged: (date) {
      setState(() => _endTime = date.toLocalTime());
    },
    validator: (date) {
      if (date == null) {
        return 'You must select an End Date';
      }
      final endTime = date.toLocalTime();
      if (endTime.isBefore(_startTime)) {
        return 'Must be after start date.';
      } else {
        return null;
      }
    },
  );

  /// Start Date
  HMBDateTimeField _buildStartDate() => HMBDateTimeField(
    mode: HMBDateTimeFieldMode.timeOnly,
    label: 'Start Time',
    initialDateTime: _startTime.toDateTime(),
    width: 200,
    onChanged: (date) {
      _startTime = date.toLocalTime();
      if (_startTime.isAfter(_endTime)) {
        _endTime = _startTime.addDuration(const Duration(hours: 1));
      }
      setState(() => {});
    },
  );

  /// If the user taps “Delete,” we pop null
  /// to indicate a delete request.
  void _handleDelete() {
    Navigator.of(
      context,
    ).pop(JobActivityUpdateAction(EditAction.delete, widget.event!.event));
  }

  /// Save Event
  Future<void> _handleSave() async {
    if (!(_form.currentState?.validate() ?? true)) {
      return;
    }

    if (_selectedJob == null) {
      HMBToast.error('Please select a job for the event.');

      return;
    }

    if (_startTime.isAfterOrEqual(_endTime)) {
      HMBToast.error('The end time must be after the start time.');
      return;
    }

    if (_startTime.atDate(_eventDate).isBefore(DateTime.now())) {
      HMBToast.error('The Start date and time must be in the future..');
      return;
    }

    /// To ensure that the end date is on the same day as the start
    /// date, if the user chooses 12am (midnight) as the end date
    /// we roll it back 1 minute so it falls on the same day.
    if (_endTime == const LocalTime(hour: 24, minute: 00)) {
      _endTime = _endTime
          .atDate(_eventDate)
          .subtract(const Duration(minutes: 1))
          .toLocalTime();
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
            '(${formatDateTime(overlappingEvent.jobActivity.start)} - ${formatDateTime(overlappingEvent.jobActivity.end)}). '
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

    late JobActivity jobEvent;
    if (widget.isEditing) {
      jobEvent = widget.event!.event!.jobActivity.copyWith(
        jobId: _selectedJob!.id,
        start: _startTime.atDate(_eventDate),
        end: _endTime.atDate(_eventDate),
        status: _status,
        notes: _notes,
        noticeSentDate: _noticeSentDate,
      );
    } else {
      /// new job event.
      jobEvent = JobActivity.forInsert(
        jobId: _selectedJob!.id,
        start: _startTime.atDate(_eventDate),
        end: _endTime.atDate(_eventDate),
        status: _status,
        notes: _notes,
        noticeSentDate: _noticeSentDate,
      );
    }
    final jobEventEx = await JobActivityEx.fromActivity(jobEvent);

    await _updateJobStatus();

    if (mounted) {
      if (widget.isEditing) {
        Navigator.of(
          context,
        ).pop(JobActivityUpdateAction(EditAction.update, jobEventEx));
      } else {
        Navigator.of(
          context,
        ).pop(JobActivityAddAction(AddAction.add, jobEventEx));
      }
    }
  }

  Future<JobActivityEx?> _checkForOverlappingEvents() async {
    final jobEvents = await DaoJobActivity().getByJob(_selectedJob!.id);
    for (final event in jobEvents) {
      final startDate = _startTime.atDate(_eventDate);
      final endDate = _endTime.atDate(_eventDate);
      if ((startDate.isBefore(event.end) && startDate.isAfter(event.start)) ||
          (endDate.isAfter(event.start) && endDate.isBefore(event.end)) ||
          (startDate.isBefore(event.start) && endDate.isAfter(event.end))) {
        // Exclude the current event being edited from overlap check
        if (!widget.isEditing ||
            event.id != widget.event?.event?.jobActivity.id) {
          return JobActivityEx.fromActivity(event);
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
          'on hold',
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
                  color: contact.isPrimary ? Colors.blue : null,
                ),
                title: Text(
                  contact.detail,
                  style: TextStyle(
                    fontWeight: contact.isPrimary
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  '${contact.contact.firstName} ${contact.contact.surname}',
                ),
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
          contactOptions.add(
            ContactOption(
              contact: contact,
              detail: contact.emailAddress,
              method: ContactMethod.email,
            ),
          );
        }
        if (contact.mobileNumber.isNotEmpty) {
          contactOptions.add(
            ContactOption(
              contact: contact,
              detail: contact.mobileNumber,
              method: ContactMethod.sms,
            ),
          );
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
          'Notice sent to ${contact.contact.firstName} via ${contact.method.name} (${contact.detail})',
        ),
      ),
    );

    // Record the date the notice was sent
    setState(() {
      _noticeSentDate = DateTime.now();
    });
  }

  List<Widget> _buildStartEndDates(bool isSmallScreen) {
    if (isSmallScreen) {
      return <Widget>[
        // Vertical layout for small screens
        _buildStartDate(),
        const HMBSpacer(height: true),
        _buildEndDate(context),
        const HMBSpacer(height: true),
      ];
    } else {
      return <Widget>[
        // Horizontal layout for larger screens
        Row(
          children: [
            Expanded(child: _buildStartDate()),
            const HMBSpacer(height: true),
            Expanded(child: _buildEndDate(context)),
          ],
        ),
        const HMBSpacer(height: true),
      ];
    }
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
