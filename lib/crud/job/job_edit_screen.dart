import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_job_status.dart';
import '../../dao/dao_system.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../entity/job_status.dart';
import '../../util/money_ex.dart';
import '../../util/platform_ex.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_child_crud_card.dart';
import '../../widgets/hmb_droplist.dart';
import '../../widgets/hmb_form_section.dart';
import '../../widgets/hmb_select_contact.dart';
import '../../widgets/hmb_select_site.dart';
import '../../widgets/hmb_text_field.dart';
import '../../widgets/rich_editor.dart';
import '../../widgets/select_customer.dart';
import '../base_full_screen/entity_edit_screen.dart';
import '../base_nested/nested_list_screen.dart';
import '../task/task_list_screen.dart';

class JobEditScreen extends StatefulWidget {
  const JobEditScreen({super.key, this.job});
  final Job? job;

  @override
  JobEditScreenState createState() => JobEditScreenState();
}

class JobEditScreenState extends State<JobEditScreen>
    implements EntityState<Job> {
  late TextEditingController _summaryController;
  late RichEditorController _descriptionController;
  late TextEditingController _hourlyRateController;
  late TextEditingController _callOutFeeController;

  late FocusNode _summaryFocusNode;
  late FocusNode _descriptionFocusNode;
  late FocusNode _hourlyRateFocusNode;
  late FocusNode _callOutFeeFocusNode;

  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.job?.startDate ?? DateTime.now();
    _summaryController = TextEditingController(text: widget.job?.summary ?? '');
    _descriptionController = RichEditorController(
        parchmentAsJsonString: widget.job?.description ?? '');
    _hourlyRateController =
        TextEditingController(text: widget.job?.hourlyRate?.toString() ?? '');
    _callOutFeeController =
        TextEditingController(text: widget.job?.callOutFee?.toString() ?? '');

    _summaryFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    _hourlyRateFocusNode = FocusNode();
    _callOutFeeFocusNode = FocusNode();

    /// reset the state.
    June.getState(SelectedCustomer.new).customerId = widget.job?.customerId;
    June.getState(SelectJobStatus.new).jobStatusId = widget.job?.jobStatusId;
    June.getState(SelectedSite.new).siteId = widget.job?.siteId;
    June.getState(SelectedContact.new).contactId = widget.job?.contactId;

    if (widget.job == null) {
      // ignore: discarded_futures
      DaoSystem().get().then((system) {
        setState(() {
          _hourlyRateController.text =
              system!.defaultHourlyRate?.amount.toString() ?? '0.00';
          _callOutFeeController.text =
              system.defaultCallOutFee?.amount.toString() ?? '0.00';
        });
        // Hard coded id of the 'Prospecting' status, probably not a great way
        // to do this.
        // ignore: discarded_futures
        DaoJobStatus().getById(1).then((jobStatus) {
          setState(() {
            June.getState(SelectJobStatus.new).jobStatusId = jobStatus?.id;
          });
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      JuneBuilder(() => SelectedCustomer()..customerId = widget.job?.customerId,
          builder: (selectedCustomer) => FutureBuilderEx<Customer?>(
              // ignore: discarded_futures
              future: DaoCustomer().getById(selectedCustomer.customerId),

              /// get the job details
              builder: (context, customer) => EntityEditScreen<Job>(
                  entity: widget.job,
                  entityName: 'Job',
                  dao: DaoJob(),
                  entityState: this,
                  editor: (job) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            HMBFormSection(children: [
                              _showSummary(),
                              _chooseCustomer(),
                              _chooseStatus(job),
                              _chooseDate(),
                              _showHourlyRate(),
                              _showCallOutFee(),
                              SizedBox(
                                height: 200,
                                child: RichEditor(
                                    controller: _descriptionController,
                                    focusNode: _descriptionFocusNode,
                                    key: UniqueKey()),
                                // )
                              ),
                            ]),

                            /// allow the user to select a contact for the job
                            _chooseContact(customer, job),

                            /// allow the user to select a site for the job
                            _chooseSite(customer, job),

                            _manageTasks(job),
                          ]))));

  Widget _showSummary() => HMBTextField(
        focusNode: _summaryFocusNode,
        autofocus: isNotMobile,
        controller: _summaryController,
        labelText: 'Job Summary',
        textCapitalization: TextCapitalization.sentences,
        required: true,
        keyboardType: TextInputType.name,
      );

  Widget _showHourlyRate() => HMBTextField(
        controller: _hourlyRateController,
        focusNode: _hourlyRateFocusNode,
        labelText: 'Hourly Rate',
        keyboardType: TextInputType.number,
      );

  Widget _showCallOutFee() => HMBTextField(
        controller: _callOutFeeController,
        focusNode: _callOutFeeFocusNode,
        labelText: 'Call Out Fee',
        keyboardType: TextInputType.number,
      );

  HMBChildCrudCard _manageTasks(Job? job) => HMBChildCrudCard(
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
              onSelected: (contact) => setState(() {
                    setState(() {
                      June.getState(SelectedContact.new).contactId =
                          contact?.id;
                    });
                  })));

  JuneBuilder<SelectedSite> _chooseSite(Customer? customer, Job? job) =>
      JuneBuilder(() => SelectedSite()..siteId = job?.siteId,
          builder: (state) => HMBSelectSite(
              initialSite: state,
              customer: customer,
              onSelected: (site) => setState(() {
                    setState(() {
                      June.getState(SelectedSite.new).siteId = site?.id;
                    });
                  })));

  Widget _chooseCustomer() => SelectCustomer(
        selectedCustomer: June.getState(SelectedCustomer.new),
        onSelected: (customer) => setState(() {
          setState(() {
            June.getState(SelectedCustomer.new).customerId = customer?.id;

            /// we have changed customers so the site and contact lists
            /// are no longer valid.
            June.getState(SelectedSite.new).siteId = null;
            June.getState(SelectedContact.new).contactId = null;
          });
        }),
      );

  Widget _chooseStatus(Job? job) => HMBDroplist<JobStatus>(
      title: 'Status',
      items: (filter) async => DaoJobStatus().getAll(),
      initialItem: () async => DaoJobStatus().getById(
          job?.jobStatusId ?? June.getState(SelectJobStatus.new).jobStatusId),
      onChanged: (status) =>
          June.getState(SelectJobStatus.new).jobStatusId = status.id,
      format: (value) => value.name);

  HMBButton _chooseDate() => HMBButton(
        onPressed: _selectDate,
        label: 'Scheduled: ${_selectedDate.toLocal()}'.split(' ')[0],
      );

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015, 8),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

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
      callOutFee: MoneyEx.tryParse(_callOutFeeController.text));

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
      callOutFee: MoneyEx.tryParse(_callOutFeeController.text));

  @override
  void dispose() {
    _summaryController.dispose();
    _descriptionController.dispose();
    _hourlyRateController.dispose();
    _callOutFeeController.dispose();
    _summaryFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _hourlyRateFocusNode.dispose();
    _callOutFeeFocusNode.dispose();
    super.dispose();
  }

  @override
  void refresh() {
    setState(() {});
  }
}

class SelectJobStatus {
  SelectJobStatus();

  int? jobStatusId;
}
