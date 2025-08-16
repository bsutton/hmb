// Extracted editor card
import 'dart:async';
import 'dart:convert';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/app_title.dart';
import '../../../util/date_time_ex.dart';
import '../../../util/format.dart';
import '../../../util/local_date.dart';
import '../../../util/platform_ex.dart';
import '../../../util/rich_text_helper.dart';
import '../../scheduling/schedule_page.dart';
import '../../widgets/circle.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/help_button.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/hmb_form_section.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/media/photo_gallery.dart';
import '../../widgets/media/rich_editor.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/select/hmb_select_contact.dart';
import '../../widgets/select/hmb_select_customer.dart';
import '../../widgets/select/hmb_select_site.dart';
import '../../widgets/text/hmb_expanding_text_block.dart';
import '../../widgets/text/hmb_text.dart';
import 'edit_job_screen.dart';
import 'fsm_status_picker.dart';
import 'list_job_screen.dart';

class EditJobCard extends StatefulWidget {
  const EditJobCard({
    required this.job,
    required this.customer,
    required this.summaryController,
    required this.descriptionController,
    required this.assumptionController,
    required this.hourlyRateController,
    required this.bookingFeeController,
    required this.summaryFocusNode,
    required this.descriptionFocusNode,
    required this.assumptionFocusNode,
    required this.hourlyRateFocusNode,
    required this.bookingFeeFocusNode,
    required this.selectedBillingType,
    required this.onBillingTypeChanged,
    super.key,
  });

  final Job? job;
  final Customer? customer;

  // Controllers
  final TextEditingController summaryController;
  final RichEditorController descriptionController;
  final RichEditorController assumptionController;
  final TextEditingController hourlyRateController;
  final TextEditingController bookingFeeController;

  // Focus nodes
  final FocusNode summaryFocusNode;
  final FocusNode descriptionFocusNode;
  final FocusNode assumptionFocusNode;
  final FocusNode hourlyRateFocusNode;
  final FocusNode bookingFeeFocusNode;

  // Billing type state is owned by parent (so saves still work there).
  final BillingType selectedBillingType;
  final ValueChanged<BillingType> onBillingTypeChanged;

  @override
  State<EditJobCard> createState() => _EditJobCardState();
}

class _EditJobCardState extends State<EditJobCard> {
  // Version counters to force RichEditor text refresh
  var _descriptionVersion = 0;
  var _assumptionVersion = 0;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const HMBSpacer(height: true),
      HMBFormSection(
        children: [
          _showSummary(),
          _chooseCustomer(),
          _chooseStatus(widget.job),
          if (widget.job != null) _buildScheduleButtons(),
          _chooseBillingType(),
          _chooseBillingContact(),
          _showHourlyRate(),
          _showBookingFee(),
          const HMBSpacer(height: true),
          _buildDescription(),
          const SizedBox(height: 12),
          _buildAssumption(),
          const SizedBox(height: 12),
          _chooseContact(),
          _chooseSite(),
        ],
      ),
      const HMBSpacer(height: true),
      if (widget.job != null) PhotoGallery.forJob(job: widget.job!),
    ],
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
    () => SelectedSite()..siteId = widget.job?.siteId,
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

  // replace your existing _chooseStatus with this shim:
Widget _chooseStatus(Job? job) =>
    job == null ? _chooseStatusForNewJob() : FsmStatusPicker(job: job);

// keep the old dropdown for creating brand new jobs
Widget _chooseStatusForNewJob() => JuneBuilder(
  () => SelectJobStatus()..jobStatus = JobStatus.startingStatus,
  builder: (jobStatus) => HMBDroplist<JobStatus>(
    title: 'Status',
    items: (filter) async => JobStatus.byOrdinal(),
    selectedItem: () async => jobStatus.jobStatus,
    onChanged: (status) => jobStatus.jobStatus = status,
    format: (value) => value.displayName,
  ),
);


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
      final jobId = widget.job!.id;
      final firstActivity = await _getFirstActivity(jobId);
      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
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
    },
  );

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
      future: DaoJobActivity().getByJob(widget.job!.id),
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
                  defaultJob: widget.job?.id,
                  dialogMode: true,
                ),
                fullscreenDialog: true,
              ),
            );

            setAppTitle(JobListScreen.pageTitle);
            June.getState(ActivityJobsState.new).setState();
          },
          child: Row(
            children: [
              if (nextActivity != null)
                Circle(color: nextActivity.status.color, child: const Text('')),
              const SizedBox(width: 5),
              Text(
                'Activities: $nextWhen',
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
              child: Row(
                children: [
                  Circle(color: a.status.color, child: const Text('')),
                  const SizedBox(width: 5),
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

  // --- Description / Assumptions -------------------------------------------

  Widget _buildDescription() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HMBText('Description:', bold: true),
            Container(
              constraints: const BoxConstraints(minHeight: 200),
              child: HMBExpandingTextBlock(
                RichTextHelper.parchmentToPlainText(
                  widget.descriptionController.document,
                ),
                key: ValueKey(_descriptionVersion),
              ),
            ),
          ],
        ),
      ),
      IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () async {
          await _showRichEditDialog(
            widget.descriptionController,
            'Description',
          );
          setState(() => _descriptionVersion++);
        },
      ),
    ],
  );

  Widget _buildAssumption() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
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
                RichEditor.createParchment(
                  jsonEncode(widget.assumptionController.document),
                ).toPlainText().replaceAll('\n\n', '\n'),
                key: ValueKey(_assumptionVersion),
              ),
            ),
          ],
        ),
      ),
      IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () async {
          await _showRichEditDialog(widget.assumptionController, 'Assumptions');
          setState(() => _assumptionVersion++);
        },
      ),
    ],
  );

  Future<void> _showRichEditDialog(
    RichEditorController richController,
    String title,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: RichEditor(
                  controller: richController,
                  focusNode: FocusNode(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Save'),
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
  SelectedContact();

  int? _contactId;

  int? get contactId => _contactId;

  set contactId(int? value) {
    _contactId = value;
    setState();
  }
}

class SelectJobStatus extends JuneState {
  SelectJobStatus();

  JobStatus? _jobStatus = JobStatus.startingStatus;

  JobStatus? get jobStatus => _jobStatus;

  set jobStatus(JobStatus? value) {
    _jobStatus = value;
    setState();
  }
}
