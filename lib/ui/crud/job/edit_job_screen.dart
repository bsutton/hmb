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

import 'dart:async';
import 'dart:convert';

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
import '../../../util/dart/money_ex.dart';
import '../../widgets/circle.dart';
import '../../widgets/media/rich_editor.dart';
import '../../widgets/select/hmb_select_customer.dart';
import '../../widgets/select/hmb_select_site.dart';
import '../base_full_screen/edit_entity_screen.dart';
import 'edit_job_card.dart';

class JobEditScreen extends StatefulWidget {
  final Job? job;

  const JobEditScreen({super.key, this.job});
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
    June.getState(SelectedContact.new).contactId = widget.job?.contactId;
    _selectedBillingType =
        widget.job?.billingType ?? BillingType.timeAndMaterial;

    // Handle billing contact default
    final billingState = June.getState(JobBillingContact.new);
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

          editor: (job, {required isNew}) => EditJobCard(
            job: job,
            customer: customer,
            summaryController: _summaryController,
            descriptionController: _descriptionController,
            assumptionController: _assumptionController,
            hourlyRateController: _hourlyRateController,
            bookingFeeController: _bookingFeeController,
            summaryFocusNode: _summaryFocusNode,
            descriptionFocusNode: _descriptionFocusNode,
            assumptionFocusNode: _assumptionFocusNode,
            hourlyRateFocusNode: _hourlyRateFocusNode,
            bookingFeeFocusNode: _bookingFeeFocusNode,
            selectedBillingType: _selectedBillingType,
            onBillingTypeChanged: (b) {
              setState(() {
                _selectedBillingType = b;
              });
            },
          ),
        ),
      ),
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

  String _activityDisplay(JobActivity e) => formatDateTimeAM(e.start);

  @override
  Future<Job> forUpdate(Job job) async => job.copyWith(
    customerId: June.getState(SelectedCustomer.new).customerId,
    summary: _summaryController.text,
    description: jsonEncode(_descriptionController.document),
    assumption: jsonEncode(_assumptionController.document),
    siteId: June.getState(SelectedSite.new).siteId,
    contactId: June.getState(SelectedContact.new).contactId,
    status:
        June.getState(SelectJobStatus.new).jobStatus ??
        JobStatus.startingStatus,
    hourlyRate: MoneyEx.tryParse(_hourlyRateController.text),
    bookingFee: MoneyEx.tryParse(_bookingFeeController.text),
    bookingFeeInvoiced: job.bookingFeeInvoiced,
    billingType: _selectedBillingType,
    billingContactId: June.getState(JobBillingContact.new).contactId,
  );

  @override
  Future<Job> forInsert() async => Job.forInsert(
    customerId: June.getState(SelectedCustomer.new).customerId,
    summary: _summaryController.text,
    description: jsonEncode(_descriptionController.document),
    assumption: jsonEncode(_assumptionController.document),
    siteId: June.getState(SelectedSite.new).siteId,
    contactId: June.getState(SelectedContact.new).contactId,
    status:
        June.getState(SelectJobStatus.new).jobStatus ??
        JobStatus.startingStatus,
    hourlyRate: MoneyEx.tryParse(_hourlyRateController.text),
    bookingFee: MoneyEx.tryParse(_bookingFeeController.text),
    billingType: _selectedBillingType,
    billingContactId: June.getState(JobBillingContact.new).contactId,
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
}
