import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../dao/dao_customer.dart';
import '../../../dao/dao_job.dart';
import '../../../dao/dao_job_status.dart';
import '../../../dao/dao_system.dart';
import '../../../entity/customer.dart';
import '../../../entity/job.dart';
import '../../../entity/job_status.dart';
import '../../../util/format.dart';
import '../../../util/money_ex.dart';
import '../../../util/platform_ex.dart';
import '../../invoicing/list_invoice_screen.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_child_crud_card.dart';
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
import 'rapid/quote_builder_screen.dart';

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

  @override
  Job? currentEntity;

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.job;
    _selectedDate = widget.job?.startDate ?? DateTime.now();
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
              system!.defaultHourlyRate?.amount.toString() ?? '0.00';
          _bookingFeeController.text =
              system.defaultBookingFee?.amount.toString() ?? '0.00';
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
  Widget build(BuildContext context) => JuneBuilder(
        () => SelectedCustomer()..customerId = widget.job?.customerId,
        builder: (selectedCustomer) => FutureBuilderEx<Customer?>(
          // ignore: discarded_futures
          future: DaoCustomer().getById(selectedCustomer.customerId),

          /// get the job details
          builder: (context, customer) => EntityEditScreen<Job>(
            entityName: 'Job',
            dao: DaoJob(),
            entityState: this,
            editor: (job) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HMBSpacer(height: true),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (job != null) _buildQuoteButton(context, job),
                  const HMBSpacer(width: true),
                  if (job != null) _buildInvoiceButton(context, job),
                ]),
                const HMBSpacer(height: true),
                HMBFormSection(children: [
                  _showSummary(),
                  _chooseCustomer(),
                  _chooseStatus(job),
                  _chooseDate(),
                  _chooseBillingType(),
                  _showHourlyRate(),
                  _showBookingFee(),
                  SizedBox(
                    height: 300,
                    child: RichEditor(
                        controller: _descriptionController,
                        focusNode: _descriptionFocusNode,
                        key: UniqueKey()),
                  ),
                ]),

                // Allow the user to select a contact for the job
                _chooseContact(customer, job),

                // Allow the user to select a site for the job
                _chooseSite(customer, job),

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

  Widget _buildInvoiceButton(BuildContext context, Job job) => ElevatedButton(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (context) => InvoiceListScreen(job: job),
          ));
          setState(() {}); // Refresh the job after returning
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16),
        ),
        child: const Text('Invoice'),
      );

  Widget _buildQuoteButton(BuildContext context, Job job) => ElevatedButton(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (context) => QuoteBuilderScreen(job: job),
          ));
          setState(() {}); // Refresh the job after returning
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16),
        ),
        child: const Text('Quote'),
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
      );
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
      );

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
      items: (filter) async =>
          DaoJobStatus().getAll(orderByClause: 'ordinal asc'),
      selectedItem: () async => DaoJobStatus().getById(
          job?.jobStatusId ?? June.getState(SelectJobStatus.new).jobStatusId),
      onChanged: (status) =>
          June.getState(SelectJobStatus.new).jobStatusId = status?.id,
      format: (value) => value.name);

  Widget _chooseDate() => Padding(
        padding: const EdgeInsets.all(8),
        child: HMBButton(
          onPressed: _selectDate,
          label: 'Scheduled: ${formatDate(_selectedDate)}',
        ),
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

class SelectJobStatus {
  SelectJobStatus();

  int? jobStatusId;
}
