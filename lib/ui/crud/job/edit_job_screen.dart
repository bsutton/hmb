import 'dart:async';
import 'dart:convert';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../dao/dao_customer.dart';
import '../../../dao/dao_job.dart';
import '../../../dao/dao_job_activity.dart';
import '../../../dao/dao_job_status.dart';
import '../../../dao/dao_system.dart';
import '../../../entity/customer.dart';
import '../../../entity/job.dart';
import '../../../entity/job_activity.dart';
import '../../../entity/job_status.dart';
import '../../../util/app_title.dart';
import '../../../util/date_time_ex.dart';
import '../../../util/format.dart';
import '../../../util/local_date.dart';
import '../../../util/money_ex.dart';
import '../../../util/platform_ex.dart';
import '../../scheduling/schedule_page.dart';
import '../../widgets/circle.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/help_button.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_child_crud_card.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/hmb_form_section.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/media/photo_gallery.dart';
import '../../widgets/media/rich_editor.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/select/hmb_select_contact.dart';
import '../../widgets/select/hmb_select_site.dart';
import '../../widgets/select/select_customer.dart';
import '../base_full_screen/edit_entity_screen.dart';
import '../base_nested/list_nested_screen.dart';
import '../task/list_task_screen.dart';
import 'list_job_screen.dart';

class JobEditScreen extends StatefulWidget {
  const JobEditScreen({super.key, this.job});
  final Job? job;

  @override
  _JobEditScreenState createState() => _JobEditScreenState();
}

class _JobEditScreenState extends State<JobEditScreen>
    implements EntityState<Job> {
  late TextEditingController _summaryController;
  late RichEditorController _descriptionController;
  late TextEditingController _hourlyRateController;
  late TextEditingController _bookingFeeController;

  late FocusNode _summaryFocusNode;
  late FocusNode _descriptionFocusNode;
  late FocusNode _hourlyRateFocusNode;
  late FocusNode _bookingFeeFocusNode;

  late DateTime _selectedDate;
  BillingType _selectedBillingType = BillingType.timeAndMaterial;
  late final ScrollController scrollController;

  @override
  Job? currentEntity;

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.job;
    _selectedDate = widget.job?.startDate ?? DateTime.now();

    scrollController = ScrollController();

    _summaryController = TextEditingController(text: widget.job?.summary ?? '');
    _descriptionController = RichEditorController(
        parchmentAsJsonString: widget.job?.description ?? '');
    _hourlyRateController =
        TextEditingController(text: widget.job?.hourlyRate?.toString() ?? '');
    _bookingFeeController =
        TextEditingController(text: widget.job?.bookingFee?.toString() ?? '');

    _summaryFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    _hourlyRateFocusNode = FocusNode();
    _bookingFeeFocusNode = FocusNode();

    /// reset the state.
    June.getState(SelectedCustomer.new).customerId = widget.job?.customerId;
    June.getState(SelectJobStatus.new).jobStatusId = widget.job?.jobStatusId;
    June.getState(SelectedSite.new).siteId = widget.job?.siteId;
    June.getState(SelectedContact.new).contactId = widget.job?.contactId;

    _selectedBillingType =
        widget.job?.billingType ?? BillingType.timeAndMaterial;

    if (widget.job == null) {
      // ignore: discarded_futures
      DaoSystem().get().then((system) {
        setState(() {
          _hourlyRateController.text =
              system.defaultHourlyRate?.amount.toString() ?? '0.00';
          _bookingFeeController.text =
              system.defaultBookingFee?.amount.toString() ?? '0.00';
        });
        // Hard coded id of the 'Prospecting' status, probably not a great way
        // to do this.
        // ignore: discarded_futures
        DaoJobStatus().getById(1).then((jobStatus) {
          June.getState(SelectJobStatus.new).jobStatusId = jobStatus?.id;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) => JuneBuilder(
        () => SelectedCustomer()..customerId = widget.job?.customerId,
        builder: (selectedCustomer) => FutureBuilderEx<Customer?>(
          // ignore: discarded_futures
          future: DaoCustomer().getById(selectedCustomer.customerId),

          /// get the job details
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
                HMBFormSection(children: [
                  _showSummary(),
                  _chooseCustomer(),
                  _chooseStatus(job),
                  if (widget.job != null) _buildScheduleButtons(),
                  _chooseBillingType(),
                  _showHourlyRate(),
                  _showBookingFee(),
                  const HMBSpacer(height: true),
                  SizedBox(
                    height: 300,
                    child: RichEditor(
                        controller: _descriptionController,
                        focusNode: _descriptionFocusNode,
                        key: ValueKey(job?.description)),
                  ),
                  // Allow the user to select a contact for the job
                  _chooseContact(customer, job),

                  // Allow the user to select a site for the job
                  _chooseSite(customer, job),
                ]),

                const HMBSpacer(height: true),

                // Display task photos
                if (job != null) PhotoGallery.forJob(job: job),

                // Manage tasks
                _manageTasks(job),

                // Remove the quote button (assuming it was here)
              ],
            ),
          ),
        ),
      );

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

  Widget _chooseBillingType() => HMBDroplist<BillingType>(
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
  Widget _showHourlyRate() => HMBTextField(
        key: const Key('hourlyRate'),
        controller: _hourlyRateController,
        focusNode: _hourlyRateFocusNode,
        labelText: 'Hourly Rate',
        keyboardType: TextInputType.number,
      );

  Widget _showBookingFee() => HMBTextField(
        key: const Key('bookingFee'),
        controller: _bookingFeeController,
        focusNode: _bookingFeeFocusNode,
        labelText: 'Booking Fee',
        keyboardType: TextInputType.number,
      ).help('Booking Fee', '''
A once off fee applied to this Job.

You can set a default booking fee from System | Billing screen''');

  Widget _manageTasks(Job? job) => HMBChildCrudCard(
        // headline: 'Tasks',
        crudListScreen: TaskListScreen(
          parent: Parent(job),
          extended: true,
        ),
      );

  JuneBuilder<SelectedContact> _chooseContact(Customer? customer, Job? job) =>
      JuneBuilder(() => SelectedContact()..contactId = job?.contactId,
          builder: (state) => HMBSelectContact(
              selectedContact: state,
              customer: customer,
              onSelected: (contact) =>
                  June.getState(SelectedContact.new).contactId = contact?.id));

  JuneBuilder<SelectedSite> _chooseSite(Customer? customer, Job? job) =>
      JuneBuilder(() => SelectedSite()..siteId = job?.siteId,
          builder: (state) => HMBSelectSite(
              initialSite: state,
              customer: customer,
              onSelected: (site) =>
                  June.getState(SelectedSite.new).siteId = site?.id));

  Widget _chooseCustomer() => SelectCustomer(
      selectedCustomer: June.getState(SelectedCustomer.new),
      onSelected: (customer) {
        June.getState(SelectedCustomer.new).customerId = customer?.id;

        /// we have changed customers so the site and contact lists
        /// are no longer valid.
        June.getState(SelectedSite.new).siteId = null;
        June.getState(SelectedContact.new).contactId = null;
      });

  Widget _chooseStatus(Job? job) =>
      JuneBuilder(() => SelectJobStatus()..jobStatusId = job?.jobStatusId,
          builder: (jobStatus) => HMBDroplist<JobStatus>(
              title: 'Status',
              items: (filter) async =>
                  DaoJobStatus().getAll(orderByClause: 'ordinal asc'),
              selectedItem: () async =>
                  DaoJobStatus().getById(jobStatus.jobStatusId),
              onChanged: (status) => jobStatus.jobStatusId = status?.id,
              format: (value) => value.name));

  Widget _buildScheduleButtons() => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(children: [
          _buildScheduleButton(),
          const HMBSpacer(width: true),
          _buildActivityButton()
        ]),
      );

  Widget _buildScheduleButton() => HMBButton(
      label: 'Schedule',
      onPressed: () async {
        if ((await DaoSystem().get()).getOperatingHours().noOpenDays()) {
          HMBToast.error(
              "Before you Schedule a job, you must first set your opening hours from the 'System | Business' page.");
          return;
        }
        final jobId = widget.job!.id;

        final firstActivity = await _getFirstActivity();

        if (mounted) {
          // Fetch upcoming activity for that job
          // If no activities, just open schedule set to week/today
          await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => SchedulePage(
                    defaultView: ScheduleView.week,
                    initialActivityId: firstActivity?.id,
                    defaultJob: jobId,
                    dialogMode: true,
                  ),
              fullscreenDialog: true));

          /// We need to reset the title as the Schedule Page
          /// will have updated it.
          setAppTitle(JobListScreen.pageTitle);
          June.getState(ActivityJobsState.new).setState();
        }
      });

  Future<JobActivity?> _getFirstActivity() async {
    final now = DateTime.now();

    final daoJobActivity = DaoJobActivity();
    final jobActivities = await daoJobActivity.getByJob(widget.job!.id);
    JobActivity? nextActivity;
    for (final e in jobActivities) {
      if (e.start.isAfter(now)) {
        nextActivity = e;
        break;
      }
    }
    return nextActivity;
  }

  Widget _buildActivityButton() => JuneBuilder(ActivityJobsState.new,
      builder: (context) => FutureBuilderEx(
          // ignore: discarded_futures
          future: DaoJobActivity().getByJob(widget.job!.id),
          builder: (context, jobActivities) {
            final nextActivity = _nextAcitivty(jobActivities!);
            final nextActivityWhen = nextActivity == null
                ? ''
                : formatDateTimeAM(nextActivity.start);
            return ElevatedButton(
              onPressed: () async {
                // Find the next upcoming activity
                if (mounted) {
                  // Display a droplist or a simple dialog?
                  // For demonstration, let's do a showDialog with the list:
                  final selectedActivity =
                      await showActivityDialog(jobActivities);

                  if (context.mounted && selectedActivity != null) {
                    // Now open schedule page showing that activities date in Week view
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => SchedulePage(
                              defaultView: ScheduleView.week,
                              initialActivityId: selectedActivity.id,
                              defaultJob: widget.job?.id,
                              dialogMode: true,
                            ),
                        fullscreenDialog: true));

                    /// We need to reset the title as the Schedule Page
                    /// will have updated it.
                    setAppTitle(JobListScreen.pageTitle);
                    // refresh the list of activities.
                    June.getState(ActivityJobsState.new).setState();
                  }
                }
              },
              child: Row(
                children: [
                  if (nextActivity != null)
                    Circle(
                        color: nextActivity.status.color,
                        child: const Text('')),
                  const SizedBox(width: 5),
                  Text('Activities: $nextActivityWhen',
                      style: TextStyle(
                        color:
                            nextActivity != null && _isToday(nextActivity.start)
                                ? Colors.orangeAccent
                                : Colors.white,
                      ))
                ],
              ),
            );
          }));

  ///
  /// show activity Dialog
  ///
  Future<JobActivity?> showActivityDialog(
      List<JobActivity> jobActivities) async {
    final today = DateTime.now().withoutTime;
    return showDialog<JobActivity>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Open an Activity'),
        children: [
          // "Next Activity" first, if any
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(_nextAcitivty(jobActivities)),
            child: Text('Next Activity: ${_nextAcctivityWhen(jobActivities)}'),
          ),

          // Then list all
          for (final jobActivity in jobActivities)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(jobActivity),
              child: Row(
                children: [
                  Circle(
                      color: jobActivity.status.color, child: const Text('')),
                  const SizedBox(width: 5),
                  Text(_activityDisplay(jobActivity),
                      style: TextStyle(
                          decoration: (jobActivity.start.isBefore(today))
                              ? TextDecoration.lineThrough
                              : TextDecoration.none)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _nextAcctivityWhen(List<JobActivity> jobActivities) {
    final next = _nextActivityDate(jobActivities);
    return next == null ? '' : formatDateTimeAM(next);
  }

  DateTime? _nextActivityDate(List<JobActivity> jobActivities) =>
      _nextAcitivty(jobActivities)?.start;

  JobActivity? _nextAcitivty(List<JobActivity> jobActivities) {
    final today = LocalDate.today();
    for (final e in jobActivities) {
      if (e.start.toLocalDate().isAfter(today) ||
          e.start.toLocalDate() == today) {
        return e;
      }
    }
    return null;
  }

  bool _isToday(DateTime nextActivity) => nextActivity.toLocalDate().isToday;

  String _activityDisplay(JobActivity e) => formatDateTimeAM(e.start);

  @override
  Future<Job> forUpdate(Job job) async => Job.forUpdate(
        entity: job,
        customerId: June.getState(SelectedCustomer.new).customerId,
        summary: _summaryController.text,
        description: jsonEncode(_descriptionController.document),
        startDate: _selectedDate,
        siteId: June.getState(SelectedSite.new).siteId,
        contactId: June.getState(SelectedContact.new).contactId,
        jobStatusId: June.getState(SelectJobStatus.new).jobStatusId,
        hourlyRate: MoneyEx.tryParse(_hourlyRateController.text),
        bookingFee: MoneyEx.tryParse(_bookingFeeController.text),
        billingType: _selectedBillingType,
      );

  @override
  Future<Job> forInsert() async => Job.forInsert(
        customerId: June.getState(SelectedCustomer.new).customerId,
        summary: _summaryController.text,
        description: jsonEncode(_descriptionController.document),
        startDate: _selectedDate,
        siteId: June.getState(SelectedSite.new).siteId,
        contactId: June.getState(SelectedContact.new).contactId,
        jobStatusId: June.getState(SelectJobStatus.new).jobStatusId,
        hourlyRate: MoneyEx.tryParse(_hourlyRateController.text),
        bookingFee: MoneyEx.tryParse(_bookingFeeController.text),
        billingType: _selectedBillingType,
      );

  @override
  void dispose() {
    scrollController.dispose();
    _summaryController.dispose();
    _descriptionController.dispose();
    _hourlyRateController.dispose();
    _bookingFeeController.dispose();
    _summaryFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _hourlyRateFocusNode.dispose();
    _bookingFeeFocusNode.dispose();
    super.dispose();
  }

  @override
  void refresh() {
    setState(() {});
  }
}

class SelectJobStatus extends JuneState {
  SelectJobStatus();

  int? jobStatusId;
}

class ActivityJobsState extends JuneState {}
