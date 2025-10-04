/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// Extracted editor card
import 'dart:async';

import 'package:calendar_view/calendar_view.dart';
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../entity/flutter_extensions/job_activity_status_ex.dart';
import '../../../util/dart/date_time_ex.dart';
import '../../../util/dart/format.dart';
import '../../../util/dart/local_date.dart';
import '../../../util/flutter/app_title.dart';
import '../../../util/flutter/platform_ex.dart';
import '../../scheduling/schedule_page.dart';
import '../../widgets/icons/circle.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/icons/help_button.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_chip.dart';
import '../../widgets/icons/hmb_edit_icon.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/media/photo_gallery.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/select/hmb_select_contact.dart';
import '../../widgets/select/hmb_select_customer.dart';
import '../../widgets/select/hmb_select_site.dart';
import '../../widgets/text/hmb_expanding_text_block.dart';
import '../../widgets/text/hmb_text.dart';
import 'fsm_status_picker.dart';
import 'list_job_screen.dart';

class EditJobCard extends StatefulWidget {
  final Job? job;
  final Customer? customer;

  // Controllers
  final TextEditingController summaryController;
  final TextEditingController descriptionController;
  final TextEditingController notesController; // NEW
  final TextEditingController assumptionController;
  final TextEditingController hourlyRateController;
  final TextEditingController bookingFeeController;

  // Focus nodes
  final FocusNode summaryFocusNode;
  final FocusNode descriptionFocusNode;
  final FocusNode notesFocusNode; // NEW
  final FocusNode assumptionFocusNode;
  final FocusNode hourlyRateFocusNode;
  final FocusNode bookingFeeFocusNode;

  // Billing type state is owned by parent (so saves still work there).
  final BillingType selectedBillingType;
  final ValueChanged<BillingType> onBillingTypeChanged;

  const EditJobCard({
    required this.job,
    required this.customer,
    required this.summaryController,
    required this.descriptionController,
    required this.notesController, // NEW
    required this.assumptionController,
    required this.hourlyRateController,
    required this.bookingFeeController,
    required this.summaryFocusNode,
    required this.descriptionFocusNode,
    required this.notesFocusNode, // NEW
    required this.assumptionFocusNode,
    required this.hourlyRateFocusNode,
    required this.bookingFeeFocusNode,
    required this.selectedBillingType,
    required this.onBillingTypeChanged,
    super.key,
  });

  @override
  State<EditJobCard> createState() => _EditJobCardState();
}

class _EditJobCardState extends DeferredState<EditJobCard> {
  // Version counters to force TextAreaEditors to refresh
  var _descriptionVersion = 0;
  var _notesVersion = 0; // NEW
  var _assumptionVersion = 0;

  Job? job;

  @override
  void initState() {
    super.initState();
    job = widget.job;
  }

  @override
  Future<void> asyncInitState() async {
    if (widget.job != null) {
      await DaoJob().markActive(widget.job!.id);
    }
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => HMBColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HMBFormSection(
          children: [
            _showSummary(),
            _chooseCustomer(),
            _chooseStatus(job),
            if (job != null) _buildScheduleButtons(),
            _chooseBillingType(),
            _chooseBillingContact(),
            _showHourlyRate(),
            _showBookingFee(),
            _buildDescription(),
            _buildNotes(),
            _buildAssumption(),
            _chooseContact(),
            _chooseSite(),
          ],
        ),
        if (job != null) PhotoGallery.forJob(job: job!),
      ],
    ),
  );

  // --- Field builders -------------------------------------------------------

  Widget _showSummary() => HMBTextField(
    key: const Key('jobSummary'),
    focusNode: widget.summaryFocusNode,
    autofocus: isNotMobile,
    controller: widget.summaryController,
    labelText: 'Job Summary',
    textCapitalization: TextCapitalization.sentences,
    required: true,
    keyboardType: TextInputType.name,
  );

  Widget _chooseBillingType() =>
      HMBDroplist<BillingType>(
        title: 'Billing Type',
        items: (filter) async => BillingType.values,
        selectedItem: () async => widget.selectedBillingType,
        onChanged: (billingType) {
          if (billingType != null) {
            widget.onBillingTypeChanged(billingType);
          }
          setState(() {});
        },
        format: (value) => value.display,
      ).help('Billing Type', '''
Time and Materials (Cost Plus)

Bill the customer based on hours tracked and Task Items purchased.
You can progressively invoice the customer during the Job.

Navigate to Billing | Invoices

Fixed Price
Bills the customer a pre-agreed amount.

You can create Milestone Invoices as the Job progresses.
Navigate to Billing | Milestones.
''');

  Widget _showHourlyRate() => HMBTextField(
    key: const Key('hourlyRate'),
    controller: widget.hourlyRateController,
    focusNode: widget.hourlyRateFocusNode,
    labelText: 'Hourly Rate',
    keyboardType: TextInputType.number,
  );

  Widget _showBookingFee() =>
      HMBTextField(
        key: const Key('bookingFee'),
        controller: widget.bookingFeeController,
        focusNode: widget.bookingFeeFocusNode,
        labelText: 'Booking Fee',
        keyboardType: TextInputType.number,
      ).help('Booking Fee', '''
A once off fee applied to this Job.

You can set a default booking fee from System | Billing screen''');

  // --- Selectors ------------------------------------------------------------

  Widget _chooseBillingContact() => JuneBuilder(
    JobBillingContact.new,
    builder: (state) => HMBSelectContact(
      key: ValueKey(state.contactId),
      title: 'Billing Contact',
      initialContact: state.contactId,
      customer: widget.customer,
      onSelected: (contact) {
        June.getState(JobBillingContact.new).contactId = contact?.id;
      },
    ),
  );

  Widget _chooseContact() => JuneBuilder(
    SelectedContact.new,
    builder: (selectedContact) => HMBSelectContact(
      key: ValueKey(selectedContact.contactId),
      initialContact: selectedContact.contactId,
      customer: widget.customer,
      onSelected: (contact) {
        June.getState(SelectedContact.new).contactId = contact?.id;
      },
    ),
  );

  JuneBuilder<SelectedSite> _chooseSite() => JuneBuilder(
    () => SelectedSite()..siteId = job?.siteId,
    builder: (state) => HMBSelectSite(
      key: ValueKey(state.siteId),
      initialSite: state,
      customer: widget.customer,
      onSelected: (site) {
        June.getState(SelectedSite.new).siteId = site?.id;
      },
    ),
  );

  Widget _chooseCustomer() => HMBSelectCustomer(
    required: true,
    selectedCustomer: June.getState(SelectedCustomer.new),
    onSelected: (customer) {
      June.getState(SelectedCustomer.new).customerId = customer?.id;

      // Clear dependent selections
      June.getState(SelectedSite.new).siteId = null;
      June.getState(SelectedContact.new).contactId = null;

      // Reset billing contact to the customer's default
      June.getState(JobBillingContact.new).contactId =
          customer?.billingContactId;

      // Pull the customer's rate into the text field
      setState(() {
        widget.hourlyRateController.text =
            customer?.hourlyRate.amount.toString() ?? '';
      });
    },
  );

  Widget _chooseStatus(Job? job) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: HMBRow(
      children: [
        const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
        JuneBuilder(
          SelectJobStatus.new,
          builder: (selectedJobStatus) => HMBChip(
            label:
                selectedJobStatus.jobStatus?.displayName ??
                JobStatus.startingStatus.displayName,
          ),
        ),
        HMBButton(
          enabled: job != null,
          label: 'Update',
          hint: 'Change job status',
          onPressed: () async {
            await showJobStatusDialog(context, job!);
            setState(() {});
          },
        ),
      ],
    ),
  );
  // Alternative dropdown version kept for reference:
  // Widget _chooseStatus(Job? job) => JuneBuilder(
  //   () => SelectJobStatus()..jobStatus = job?.status,
  //   builder: (jobStatus) => HMBDroplist<JobStatus>(
  //     title: 'Status',
  //     items: (filter) async => JobStatus.byOrdinal(),
  //     selectedItem: () async => jobStatus.jobStatus,
  //     onChanged: (status) => jobStatus.jobStatus = status,
  //     format: (value) => value.displayName,
  //   ),
  // );

  // --- Schedule / Activities -----------------------------------------------

  Widget _buildScheduleButtons() => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Row(
      children: [
        _buildScheduleButton(),
        const HMBSpacer(width: true),
        _buildActivityButton(),
      ],
    ),
  );

  Widget _buildScheduleButton() => HMBButton(
    label: 'Schedule',
    hint: 'Schedule this Job',
    onPressed: () async {
      if ((await DaoSystem().get()).getOperatingHours().noOpenDays()) {
        HMBToast.error(
          'Before you Schedule a job, you must first set your '
          "opening hours from the 'System | Business' page.",
        );
        return;
      }
      final jobId = job!.id;
      final firstActivity = await _getFirstActivity(jobId);
      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => SchedulePage(
            defaultView: ScheduleView.week,
            initialActivityId: firstActivity?.id,
            defaultJob: jobId,
            dialogMode: true,
          ),
          fullscreenDialog: true,
        ),
      );

      setAppTitle(JobListScreen.pageTitle);
      June.getState(ActivityJobsState.new).setState();

      await _checkIfScheduled();
      setState(() {});
    },
  );

  Future<void> _checkIfScheduled() async {
    // reload the job as it's state may have changed
    final tempJob = await DaoJob().getById(job?.id);
    if (tempJob!.status == JobStatus.scheduled) {
      June.getState(SelectJobStatus.new)
        ..jobStatus = JobStatus.scheduled
        ..setState();
    }
  }

  Future<JobActivity?> _getFirstActivity(int jobId) async {
    final now = DateTime.now();
    final dao = DaoJobActivity();
    final list = await dao.getByJob(jobId);
    for (final e in list) {
      if (e.start.isAfter(now)) {
        return e;
      }
    }
    return null;
  }

  Widget _buildActivityButton() => JuneBuilder(
    ActivityJobsState.new,
    builder: (context) => FutureBuilderEx<List<JobActivity>>(
      future: DaoJobActivity().getByJob(job!.id),
      builder: (context, activities) {
        final jobActivities = activities ?? [];
        final nextActivity = _nextActivity(jobActivities);
        final nextWhen = nextActivity == null
            ? ''
            : formatDateTimeAM(nextActivity.start);
        return ElevatedButton(
          onPressed: () async {
            final selected = await _showActivityDialog(jobActivities);
            if (!context.mounted || selected == null) {
              return;
            }

            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SchedulePage(
                  defaultView: ScheduleView.week,
                  initialActivityId: selected.id,
                  defaultJob: job?.id,
                  dialogMode: true,
                ),
                fullscreenDialog: true,
              ),
            );

            setAppTitle(JobListScreen.pageTitle);
            June.getState(ActivityJobsState.new).setState();
            await _checkIfScheduled();
          },
          child: HMBRow(
            children: [
              if (nextActivity != null)
                Circle(color: nextActivity.status.color, child: const Text('')),
              Text(
                'Next: $nextWhen',
                style: TextStyle(
                  color: nextActivity != null && _isToday(nextActivity.start)
                      ? Colors.orangeAccent
                      : Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<JobActivity?> _showActivityDialog(List<JobActivity> activities) {
    final today = DateTime.now().withoutTime;
    return showDialog<JobActivity>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Open an Activity'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(_nextActivity(activities)),
            child: Text('Next Activity: ${_nextActivityWhen(activities)}'),
          ),
          for (final a in activities)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(a),
              child: HMBRow(
                children: [
                  Circle(color: a.status.color, child: const Text('')),
                  Text(
                    _activityDisplay(a),
                    style: TextStyle(
                      decoration: a.start.isBefore(today)
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _nextActivityWhen(List<JobActivity> activities) {
    final next = _nextActivity(activities);
    return next == null ? '' : formatDateTimeAM(next.start);
  }

  JobActivity? _nextActivity(List<JobActivity> list) {
    final today = LocalDate.today();
    for (final e in list) {
      final ld = e.start.toLocalDate();
      if (ld.isAfter(today) || ld == today) {
        return e;
      }
    }
    return null;
  }

  bool _isToday(DateTime dt) => dt.toLocalDate().isToday;

  String _activityDisplay(JobActivity e) => formatDateTimeAM(e.start);

  // --- Description / Notes / Assumptions -----------------------------------

  Widget _buildDescription() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HMBText('Description:', bold: true),
            Container(
              constraints: const BoxConstraints(minHeight: 200),
              child: HMBExpandingTextBlock(
                widget.descriptionController.text,
                key: ValueKey(_descriptionVersion),
              ),
            ),
          ],
        ),
      ),
      HMBEditIcon(
        onPressed: () async {
          final text = await _showTextAreaEditDialog(
            widget.descriptionController.text,
            'Description',
          );
          if (text != null) {
            widget.descriptionController.text = text;
          }
          setState(() => _descriptionVersion++);
        },
        hint: 'Edit Description',
      ),
    ],
  );

  Widget _buildNotes() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HMBText('Internal Notes:', bold: true),
            Container(
              constraints: const BoxConstraints(minHeight: 200),
              child: HMBExpandingTextBlock(
                widget.notesController.text,
                key: ValueKey(_notesVersion),
              ),
            ),
          ],
        ),
      ),
      HMBEditIcon(
        onPressed: () async {
          final text = await _showTextAreaEditDialog(
            widget.notesController.text,
            'Notes',
          );
          if (text != null) {
            widget.notesController.text = text;
          }
          setState(() => _notesVersion++);
        },
        hint: 'Edit Notes',
      ),
    ],
  );

  Widget _buildAssumption() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HMBText('Assumption:', bold: true).help(
              'Assumptions',
              'Detail the assumptions your pricing is based on. '
                  'Assumptions are shown on the Quote. ',
            ),
            Container(
              constraints: const BoxConstraints(minHeight: 200),
              child: HMBExpandingTextBlock(
                widget.assumptionController.text,
                key: ValueKey(_assumptionVersion),
              ),
            ),
          ],
        ),
      ),
      HMBEditIcon(
        onPressed: () async {
          final text = await _showTextAreaEditDialog(
            widget.assumptionController.text,
            'Assumptions',
          );

          if (text != null) {
            widget.assumptionController.text = text;
          }
          setState(() => _assumptionVersion++);
        },
        hint: 'Edit Assumptions',
      ),
    ],
  );

  Future<String?> _showTextAreaEditDialog(String text, String title) {
    final localController = TextEditingController(text: text);
    return showDialog<String?>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: HMBColumn(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 300,
                child: HMBTextArea(
                  labelText: title,
                  controller: localController,
                  focusNode: FocusNode(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  HMBButton(
                    label: 'Cancel',
                    hint: 'Close the dialog without saving any changes',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  HMBButton(
                    label: 'Save',
                    hint: 'Save any changes',
                    onPressed: () =>
                        Navigator.of(context).pop(localController.text),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// State object to persist the selected billing contact ID across this screen.
class JobBillingContact extends JuneState {
  int? _contactId;

  int? get contactId => _contactId;

  set contactId(int? value) {
    _contactId = value;
    setState();
  }
}

/// State object to persist the selected contact ID across screens.
class SelectedContact extends JuneState {
  int? _contactId;

  SelectedContact();

  int? get contactId => _contactId;

  set contactId(int? value) {
    _contactId = value;
    setState();
  }
}

class SelectJobStatus extends JuneState {
  JobStatus? _jobStatus = JobStatus.startingStatus;
  SelectJobStatus();

  JobStatus? get jobStatus => _jobStatus;

  set jobStatus(JobStatus? value) {
    _jobStatus = value;
    setState();
  }
}

/// Used to rebuild the activity button when
/// a job gets scheduled.
class ActivityJobsState extends JuneState {}
