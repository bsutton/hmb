/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';
import 'dart:convert';

import 'package:calendar_view/calendar_view.dart';
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/app_title.dart';
import '../../../util/date_time_ex.dart';
import '../../../util/format.dart';
import '../../../util/local_date.dart';
import '../../../util/money_ex.dart';
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
import '../base_full_screen/edit_entity_screen.dart';
import 'list_job_screen.dart';

class JobEditScreen extends StatefulWidget {
  const JobEditScreen({super.key, this.job});
  final Job? job;

  @override
  _JobEditScreenState createState() => _JobEditScreenState();
}

class _JobEditScreenState extends DeferredState<JobEditScreen>
    implements EntityState<Job> {
  late TextEditingController _summaryController;
  late RichEditorController _descriptionController;
  late RichEditorController _assumptionController;
  late TextEditingController _hourlyRateController;
  late TextEditingController _bookingFeeController;

  late FocusNode _summaryFocusNode;
  late FocusNode _descriptionFocusNode;
  late FocusNode _assumptionFocusNode;
  late FocusNode _hourlyRateFocusNode;
  late FocusNode _bookingFeeFocusNode;

  BillingType _selectedBillingType = BillingType.timeAndMaterial;
  late final ScrollController scrollController;

  // Version counters to force RichEditor rebuild
  var _descriptionVersion = 0;
  var _assumptionVersion = 0;

  @override
  Job? currentEntity;

  late final JobStatus originalJobStatus;

  @override
  void initState() {
    super.initState();
    currentEntity ??= widget.job;
    originalJobStatus = currentEntity?.status ?? JobStatus.startingStatus;
    scrollController = ScrollController();

    _summaryController = TextEditingController(text: widget.job?.summary ?? '');
    _descriptionController = RichEditorController(
      parchmentAsJsonString: widget.job?.description ?? '',
    );
    _assumptionController = RichEditorController(
      parchmentAsJsonString: widget.job?.assumption ?? '',
    );
    _hourlyRateController = TextEditingController(
      text: widget.job?.hourlyRate?.toString() ?? '',
    );
    _bookingFeeController = TextEditingController(
      text: widget.job?.bookingFee?.toString() ?? '',
    );

    _summaryFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    _assumptionFocusNode = FocusNode();
    _hourlyRateFocusNode = FocusNode();
    _bookingFeeFocusNode = FocusNode();
  }

  @override
  Future<void> asyncInitState() async {
    // existing selections
    June.getState(SelectedCustomer.new).customerId = widget.job?.customerId;
    June.getState(SelectJobStatus.new).jobStatus = widget.job?.status;
    June.getState(SelectedSite.new).siteId = widget.job?.siteId;
    June.getState(_SelectedContact.new).contactId = widget.job?.contactId;
    _selectedBillingType =
        widget.job?.billingType ?? BillingType.timeAndMaterial;

    // Handle billing contact default
    final billingState = June.getState(_JobBillingContact.new);
    var initial = widget.job?.billingContactId;
    if (initial == null && widget.job?.customerId != null) {
      final cust = await DaoCustomer().getById(widget.job!.customerId);
      initial = cust?.billingContactId;
    }
    billingState
      ..contactId = initial
      ..setState();

    // new‐job defaults
    if (widget.job == null) {
      final system = await DaoSystem().get();
      setState(() {
        _hourlyRateController.text =
            system.defaultHourlyRate?.amount.toString() ?? '0.00';
        _bookingFeeController.text =
            system.defaultBookingFee?.amount.toString() ?? '0.00';
      });
      June.getState(SelectJobStatus.new).jobStatus = JobStatus.startingStatus;
    }
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => JuneBuilder(
      SelectedCustomer.new,
      builder: (selectedCustomer) => FutureBuilderEx<Customer?>(
        // ignore: discarded_futures
        future: DaoCustomer().getById(selectedCustomer.customerId),
        builder: (context, customer) => EntityEditScreen<Job>(
          entityName: 'Job',
          dao: DaoJob(),
          scrollController: scrollController,
          entityState: this,

          editor: (job, {required isNew}) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HMBSpacer(height: true),
              HMBFormSection(
                children: [
                  _showSummary(),
                  _chooseCustomer(),
                  _chooseStatus(job),
                  if (currentEntity != null) _buildScheduleButtons(),
                  _chooseBillingType(),
                  _chooseBillingContact(customer, job),
                  _showHourlyRate(),
                  _showBookingFee(),
                  const HMBSpacer(height: true),
                  _buildDescription(job),
                  const SizedBox(height: 12),
                  _buildAssumption(job),
                  const SizedBox(height: 12),

                  // Allow the user to select a contact for the job
                  _chooseContact(customer, job),
                  // Allow the user to select a site for the job
                  _chooseSite(customer, job),
                ],
              ),
              const HMBSpacer(height: true),
              // Display task photos
              if (job != null) PhotoGallery.forJob(job: job),
              // _manageAssignments(job),
              // _manageTasks(job),
            ],
          ),
        ),
      ),
    ),
  );

  // _showSummary
  Widget _showSummary() => HMBTextField(
    key: const Key('jobSummary'),
    focusNode: _summaryFocusNode,
    autofocus: isNotMobile,
    controller: _summaryController,
    labelText: 'Job Summary',
    textCapitalization: TextCapitalization.sentences,
    required: true,
    keyboardType: TextInputType.name,
  );

  /// _chooseBillingType
  Widget _chooseBillingType() =>
      HMBDroplist<BillingType>(
        title: 'Billing Type',
        items: (filter) async => BillingType.values,
        selectedItem: () async => _selectedBillingType,
        onChanged: (billingType) => setState(() {
          _selectedBillingType = billingType!;
        }),
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

  /// hourly rate
  Widget _showHourlyRate() => HMBTextField(
    key: const Key('hourlyRate'),
    controller: _hourlyRateController,
    focusNode: _hourlyRateFocusNode,
    labelText: 'Hourly Rate',
    keyboardType: TextInputType.number,
  );

  /// booking fee
  Widget _showBookingFee() =>
      HMBTextField(
        key: const Key('bookingFee'),
        controller: _bookingFeeController,
        focusNode: _bookingFeeFocusNode,
        labelText: 'Booking Fee',
        keyboardType: TextInputType.number,
      ).help('Booking Fee', '''
A once off fee applied to this Job.

You can set a default booking fee from System | Billing screen''');

  // /// manage tasks
  // Widget _manageTasks(Job? job) => HMBChildCrudCard(
  //   headline: 'Tasks',
  //   crudListScreen: TaskListScreen(parent: Parent(job), extended: true),
  // );

  // /// manage assignments
  // Widget _manageAssignments(Job? job) => HMBChildCrudCard(
  //   headline: 'Work Assignments',
  //   crudListScreen: AssignmentListScreen(parent: Parent(job)),
  // );

  /// choose billing contact
  Widget _chooseBillingContact(Customer? customer, Job? job) => JuneBuilder(
    _JobBillingContact.new,
    builder: (state) => HMBSelectContact(
      key: ValueKey(state.contactId),
      title: 'Billing Contact',
      initialContact: state.contactId,
      customer: customer,
      onSelected: (contact) {
        June.getState(_JobBillingContact.new).contactId = contact?.id;
      },
    ),
  );

  /// choose contact
  Widget _chooseContact(Customer? customer, Job? job) => JuneBuilder(
    _SelectedContact.new,
    builder: (state) => HMBSelectContact(
      key: ValueKey(state.contactId),
      initialContact: state.contactId,
      customer: customer,
      onSelected: (contact) {
        June.getState(_SelectedContact.new).contactId = contact?.id;
      },
    ),
  );

  JuneBuilder<SelectedSite> _chooseSite(Customer? customer, Job? job) =>
      JuneBuilder(
        () => SelectedSite()..siteId = job?.siteId,
        builder: (state) => HMBSelectSite(
          key: ValueKey(state.siteId),
          initialSite: state,
          customer: customer,
          onSelected: (site) {
            June.getState(SelectedSite.new).siteId = site?.id;
          },
        ),
      );

  /// Customer selector: when changed, clear dependent fields and re-seed defaults.
  Widget _chooseCustomer() => HMBSelectCustomer(
    selectedCustomer: June.getState(SelectedCustomer.new),
    onSelected: (customer) {
      // 1. Update the selected customer ID
      June.getState(SelectedCustomer.new).customerId = customer?.id;

      // 2. Clear site and contact selections
      June.getState(SelectedSite.new).siteId = null;

      June.getState(_SelectedContact.new).contactId = null;

      // 3. Reset billing contact to the customer's default billingContactId
      June.getState(_JobBillingContact.new).contactId =
          customer?.billingContactId;

      // 4. Pull the customer's rate (and booking-fee if you have it) into the text fields
      setState(() {
        _hourlyRateController.text =
            customer?.hourlyRate.amount.toString() ?? '';
        // if your Customer model ever gets a bookingFee field, uncomment:
        // _bookingFeeController.text = customer?.bookingFee.amount.toString() ?? '';
      });
    },
  );

  Widget _chooseStatus(Job? job) => JuneBuilder(
    () => SelectJobStatus()..jobStatus = job?.status,
    builder: (jobStatus) => HMBDroplist<JobStatus>(
      title: 'Status',
      items:
          // ignore: discarded_futures
          (filter) async => JobStatus.byOrdinal(),
      // ignore: discarded_futures
      selectedItem: () async => jobStatus._jobStatus,
      onChanged: (status) => jobStatus.jobStatus = status,
      format: (value) => value.displayName,
    ),
  );

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
          "Before you Schedule a job, you must first set your opening hours from the 'System | Business' page.",
        );
        return;
      }
      final jobId = currentEntity!.id;
      final firstActivity = await _getFirstActivity();
      if (mounted) {
        // Fetch upcoming activity for that job
        // If no activities, just open schedule set to week/today
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

        /// We need to reset the title as the Schedule Page
        /// will have updated it.
        setAppTitle(JobListScreen.pageTitle);
        June.getState(ActivityJobsState.new).setState();
      }
    },
  );

  Future<JobActivity?> _getFirstActivity() async {
    final now = DateTime.now();

    final daoJobActivity = DaoJobActivity();
    final jobActivities = await daoJobActivity.getByJob(currentEntity!.id);
    JobActivity? nextActivity;
    for (final e in jobActivities) {
      if (e.start.isAfter(now)) {
        nextActivity = e;
        break;
      }
    }
    return nextActivity;
  }

  Widget _buildActivityButton() => JuneBuilder(
    ActivityJobsState.new,
    builder: (context) => FutureBuilderEx<List<JobActivity>>(
      // ignore: discarded_futures
      future: DaoJobActivity().getByJob(currentEntity!.id),
      builder: (context, activities) {
        final jobActivities = activities ?? [];
        final nextActivity = _nextAcitivty(jobActivities);
        final nextActivityWhen = nextActivity == null
            ? ''
            : formatDateTimeAM(nextActivity.start);
        return ElevatedButton(
          onPressed: () async {
            final selectedActivity = await showActivityDialog(jobActivities);

            if (context.mounted && selectedActivity != null) {
              // Now open schedule page showing that activities date in Week view
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SchedulePage(
                    defaultView: ScheduleView.week,
                    initialActivityId: selectedActivity.id,
                    defaultJob: widget.job?.id,
                    dialogMode: true,
                  ),
                  fullscreenDialog: true,
                ),
              );

              /// We need to reset the title as the Schedule Page
              /// will have updated it.
              setAppTitle(JobListScreen.pageTitle);
              // refresh the list of activities.
              June.getState(ActivityJobsState.new).setState();
            }
          },
          child: Row(
            children: [
              if (nextActivity != null)
                Circle(color: nextActivity.status.color, child: const Text('')),
              const SizedBox(width: 5),
              Text(
                'Activities: $nextActivityWhen',
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

  Future<JobActivity?> showActivityDialog(List<JobActivity> activities) {
    final today = DateTime.now().withoutTime;
    return showDialog<JobActivity>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Open an Activity'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(_nextAcitivty(activities)),
            child: Text('Next Activity: ${_nextAcctivityWhen(activities)}'),
          ),
          for (final jobActivity in activities)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(jobActivity),
              child: Row(
                children: [
                  Circle(
                    color: jobActivity.status.color,
                    child: const Text(''),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _activityDisplay(jobActivity),
                    style: TextStyle(
                      decoration: jobActivity.start.isBefore(today)
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

  String _nextAcctivityWhen(List<JobActivity> activities) {
    final next = _nextAcitivty(activities);
    return next == null ? '' : formatDateTimeAM(next.start);
  }

  JobActivity? _nextAcitivty(List<JobActivity> jobActivities) {
    final today = LocalDate.today();
    for (final e in jobActivities) {
      final ld = e.start.toLocalDate();
      if (ld.isAfter(today) || ld == today) {
        return e;
      }
    }
    return null;
  }

  bool _isToday(DateTime dt) => dt.toLocalDate().isToday;

  String _activityDisplay(JobActivity e) => formatDateTimeAM(e.start);

  @override
  Future<Job> forUpdate(Job job) async => Job.forUpdate(
    entity: job,
    customerId: June.getState(SelectedCustomer.new).customerId,
    summary: _summaryController.text,
    description: jsonEncode(_descriptionController.document),
    assumption: jsonEncode(_assumptionController.document),
    siteId: June.getState(SelectedSite.new).siteId,
    contactId: June.getState(_SelectedContact.new).contactId,
    status:
        June.getState(SelectJobStatus.new).jobStatus ??
        JobStatus.startingStatus,
    hourlyRate: MoneyEx.tryParse(_hourlyRateController.text),
    bookingFee: MoneyEx.tryParse(_bookingFeeController.text),
    bookingFeeInvoiced: job.bookingFeeInvoiced,
    billingType: _selectedBillingType,
    billingContactId: June.getState(_JobBillingContact.new).contactId,
  );

  @override
  Future<Job> forInsert() async => Job.forInsert(
    customerId: June.getState(SelectedCustomer.new).customerId,
    summary: _summaryController.text,
    description: jsonEncode(_descriptionController.document),
    assumption: jsonEncode(_assumptionController.document),
    siteId: June.getState(SelectedSite.new).siteId,
    contactId: June.getState(_SelectedContact.new).contactId,
    status:
        June.getState(SelectJobStatus.new).jobStatus ??
        JobStatus.startingStatus,
    hourlyRate: MoneyEx.tryParse(_hourlyRateController.text),
    bookingFee: MoneyEx.tryParse(_bookingFeeController.text),
    billingType: _selectedBillingType,
    billingContactId: June.getState(_JobBillingContact.new).contactId,
  );

  @override
  void dispose() {
    scrollController.dispose();
    _summaryController.dispose();
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    _assumptionController.dispose();
    _hourlyRateController.dispose();
    _bookingFeeController.dispose();
    _summaryFocusNode.dispose();
    _assumptionFocusNode.dispose();
    _hourlyRateFocusNode.dispose();
    _bookingFeeFocusNode.dispose();
    super.dispose();
  }

  @override
  Future<void> postSave(Job entity) async {
    setState(() {});
  }

  Widget _buildDescription(Job? job) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HMBText('Description:', bold: true),
            Container(
              // This enforces a minimum height of 300 pixels
              // but allows the container to grow based on the text length.
              constraints: const BoxConstraints(minHeight: 200),
              child: HMBExpandingTextBlock(
                // Convert your RichEditor content to plain text as before
                RichTextHelper.parchmentToPlainText(
                  _descriptionController.document,
                ),

                /// the version enforces an refresh
                key: ValueKey(_descriptionVersion),
              ),
            ),
          ],
        ),
      ),
      IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () async {
          await _showRichEditDialog(_descriptionController, 'Description');
          setState(() => _descriptionVersion++);
        },
      ),
    ],
  );

  Widget _buildAssumption(Job? job) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HMBText('Assumption:', bold: true).help(
              'Assumptions',
              'Detail the assumptions your pricing is based on. Assumptions are shown on the Quote. ',
            ),
            Container(
              // This enforces a minimum height of 300 pixels
              // but allows the container to grow based on the text length.
              constraints: const BoxConstraints(minHeight: 200),
              child: HMBExpandingTextBlock(
                // Convert your RichEditor content to plain text as before
                RichEditor.createParchment(
                  jsonEncode(_assumptionController.document),
                ).toPlainText().replaceAll('\n\n', '\n'),

                /// the version enforces an refresh
                key: ValueKey(_assumptionVersion),
              ),
            ),
          ],
        ),
      ),
      IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () async {
          await _showRichEditDialog(_assumptionController, 'Assumptions');
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

class SelectJobStatus extends JuneState {
  SelectJobStatus();

  JobStatus? _jobStatus = JobStatus.startingStatus;

  JobStatus? get jobStatus => _jobStatus;

  set jobStatus(JobStatus? value) {
    _jobStatus = value;
    setState();
  }
}

class ActivityJobsState extends JuneState {}

/// State object to persist the selected contact ID across screens.
class _SelectedContact extends JuneState {
  _SelectedContact();

  int? _contactId;

  int? get contactId => _contactId;

  set contactId(int? value) {
    _contactId = value;
    setState();
  }
}

/// State object to persist the selected billing contact ID across this screen.
class _JobBillingContact extends JuneState {
  int? _contactId;

  int? get contactId => _contactId;

  set contactId(int? value) {
    _contactId = value;
    setState();
  }
}
