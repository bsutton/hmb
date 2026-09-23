import 'package:deferred_state/deferred_state.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';

import '../../../dao/dao.g.dart';
import '../../../dao/job_billing_contact.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/money_ex.dart';
import '../../../util/flutter/platform_ex.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/form_validation.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/select/hmb_select_customer.dart';
import '../../widgets/select/hmb_select_site.dart';
import '../../widgets/widgets.g.dart';
import '../base_full_screen/edit_entity_screen.dart';
import 'edit_job_card.dart';
import 'fsm_status_picker.dart';
import 'job_edit_section.dart';
import 'job_parties_screen.dart';
import 'job_summary_card.dart';

class JobEditScreen extends StatefulWidget {
  final Job? job;
  final JobEditSection? section;

  const JobEditScreen({super.key, this.job, this.section});
  @override
  State<JobEditScreen> createState() => _JobEditScreenState();
}

class _JobEditScreenState extends DeferredState<JobEditScreen>
    implements EntityState<Job> {
  final _summaryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _assumptionController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _bookingFeeController = TextEditingController();
  final _summaryFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();
  final _assumptionFocusNode = FocusNode();
  final _hourlyRateFocusNode = FocusNode();
  final _bookingFeeFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  BillingType _billingType = BillingType.timeAndMaterial;
  int? _billToId;
  int? _billingContactId;
  var _useCurrentBillingDefaults = false;
  var _revision = 0;
  var _saving = false;

  @override
  Job? currentEntity;

  @override
  Future<void> asyncInitState() async {
    await BlockingUI().runAndWait(() async {
      if (widget.job != null) {
        await DaoJob().markLastActive(widget.job!.id);
        currentEntity = await DaoJob().getById(widget.job!.id);
        if (currentEntity == null) {
          throw StateError('This job no longer exists.');
        }
      }
      await _hydrate();
    });
  }

  Future<void> _hydrate() async {
    final job = currentEntity;
    _summaryController.text = job?.summary ?? '';
    _descriptionController.text = job?.description ?? '';
    _notesController.text = job?.internalNotes ?? '';
    _assumptionController.text = job?.assumption ?? '';
    _billingType = job?.billingType ?? BillingType.timeAndMaterial;
    _hourlyRateController.text = job?.hourlyRate?.toString() ?? '0.00';
    _bookingFeeController.text = job?.bookingFee?.toString() ?? '0.00';
    _billToId = job?.billingCustomerId;
    _useCurrentBillingDefaults = false;
    _billingContactId = job?.billingContactId;
    June.getState(SelectedCustomer.new).customerId = job?.customerId;
    June.getState(SelectedReferrerCustomer.new).customerId =
        job?.referrerCustomerId;
    June.getState(SelectJobStatus.new).jobStatus = job?.status;
    June.getState(SelectedSite.new).siteId = job?.siteId;
    June.getState(SelectedContact.new).contactId = job?.contactId;
    June.getState(SelectedTenantContact.new).contactId = job?.tenantContactId;
    June.getState(SelectedReferrerContact.new).contactId =
        job?.referrerContactId;
    June.getState(SelectedBillingParty.new).billingParty =
        job?.billingParty ?? BillingParty.customer;
    June.getState(JobBillingContact.new).contactId = job?.billingContactId;
    if (job == null) {
      final system = await DaoSystem().get();
      _hourlyRateController.text =
          system.defaultHourlyRate?.amount.toString() ?? '0';
      _bookingFeeController.text =
          system.defaultBookingFee?.amount.toString() ?? '0';
    }
  }

  Future<void> _refresh() async {
    await BlockingUI().runAndWait(() async {
      currentEntity = await DaoJob().getById(currentEntity!.id);
      if (currentEntity == null) {
        throw StateError('This job no longer exists.');
      }
      await _hydrate();
    });
    if (mounted) {
      setState(() => _revision++);
    }
  }

  Future<void> _open(JobEditSection section) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JobEditScreen(job: currentEntity, section: section),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _actions() async {
    await showJobStatusDialog(context, currentEntity!);
    if (mounted) {
      await _refresh();
    }
  }

  Widget _editor(Customer? customer) => EditJobCard(
    key: ValueKey(_revision),
    job: currentEntity,
    customer: customer,
    section: widget.section,
    summaryController: _summaryController,
    descriptionController: _descriptionController,
    notesController: _notesController,
    assumptionController: _assumptionController,
    hourlyRateController: _hourlyRateController,
    bookingFeeController: _bookingFeeController,
    summaryFocusNode: _summaryFocusNode,
    descriptionFocusNode: _descriptionFocusNode,
    notesFocusNode: _notesFocusNode,
    assumptionFocusNode: _assumptionFocusNode,
    hourlyRateFocusNode: _hourlyRateFocusNode,
    bookingFeeFocusNode: _bookingFeeFocusNode,
    selectedBillingType: _billingType,
    onBillingTypeChanged: (type) => setState(() => _billingType = type),
  );

  Widget _pageShell({Widget child = const SizedBox.shrink()}) =>
      HMBFullPageChildScreen(
        title:
            widget.section?.title ??
            (widget.job == null ? 'Add Job' : 'Job #${widget.job!.id}'),
        subdued: true,
        maxContentWidth: 800,
        child: child,
      );

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    waitingBuilder: (_) => _pageShell(),
    errorBuilder: (_, error) => HMBFullPageChildScreen(
      title: 'Job',
      child: Text('Could not load job: $error'),
    ),
    builder: (context) {
      final section = widget.section;
      if (currentEntity != null && section == null) {
        return HMBFullPageChildScreen(
          title: 'Job #${currentEntity!.id}',
          subdued: true,
          maxContentWidth: 800,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: JobSummaryCard(
              revision: _revision,
              job: currentEntity!,
              onEdit: _open,
              onActions: _actions,
              onScheduleChanged: _refresh,
            ),
          ),
        );
      }
      if (section == JobEditSection.parties) {
        return JobPartiesScreen(
          job: currentEntity!,
          editCustomers: () => _open(JobEditSection.customer),
        );
      }
      return JuneBuilder(
        SelectedCustomer.new,
        builder: (selection) => FutureBuilderEx<Customer?>(
          future: BlockingUI().runAndWait(
            () => DaoCustomer().getById(selection.customerId),
          ),
          waitingBuilder: (_) => _pageShell(),
          errorBuilder: (_, error) =>
              _pageShell(child: const Text('Could not load customer.')),
          builder: (context, customer) {
            if (currentEntity == null) {
              return EntityEditScreen<Job>(
                entityName: 'Job',
                dao: DaoJob(),
                entityState: this,
                editor: (_, {required isNew}) => _editor(customer),
              );
            }
            final content = section == JobEditSection.billing
                ? _billingFields(customer)
                : _editor(customer);
            return HMBFullPageChildScreen(
              title: section!.title,
              subdued: true,
              maxContentWidth: 800,
              child: Form(
                key: _formKey,
                child:
                    section == JobEditSection.summary ||
                        section == JobEditSection.internalNotes ||
                        section == JobEditSection.assumptions
                    ? _longTextEditor(section)
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (!section.immediate) ...[
                            _sectionActions(),
                            const SizedBox(height: 16),
                          ],
                          content,
                        ],
                      ),
              ),
            );
          },
        ),
      );
    },
  );

  Widget _longTextEditor(JobEditSection section) {
    final (controller, focusNode, label, hint) = switch (section) {
      JobEditSection.summary => (
        _descriptionController,
        _descriptionFocusNode,
        'Description',
        null,
      ),
      JobEditSection.internalNotes => (
        _notesController,
        _notesFocusNode,
        'Internal notes',
        'Not shown on quotes or invoices.',
      ),
      _ => (
        _assumptionController,
        _assumptionFocusNode,
        'Assumptions',
        'Assumptions are shown on the quote.',
      ),
    };
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SizedBox(
          // In landscape with the keyboard open, keep the controls usable
          // and allow the outer form to scroll instead of overflowing.
          height: constraints.maxHeight < 320 ? 320 : constraints.maxHeight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionActions(),
                const SizedBox(height: 16),
                if (section == JobEditSection.summary)
                  HMBTextField(
                    key: const Key('jobSummary'),
                    labelText: 'Job Summary',
                    controller: _summaryController,
                    focusNode: _summaryFocusNode,
                    autofocus: isNotMobile,
                    textCapitalization: TextCapitalization.sentences,
                    required: true,
                    keyboardType: TextInputType.name,
                  )
                else
                  Text(hint!),
                const SizedBox(height: 8),
                Expanded(
                  child: HMBTextArea(
                    labelText: label,
                    controller: controller,
                    focusNode: focusNode,
                    leadingSpace: false,
                    expands: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionActions() => HMBSaveCancelButtons(
    saveEnabled: !_saving,
    saveHint: 'Save this section',
    cancelHint: 'Discard changes to this section',
    onSave: _saveSection,
    onCancel: () => Navigator.pop(context),
  );

  Widget _billingFields(Customer? customer) => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Choose whose account receives the bill. This defaults to the job '
        'customer and can be different from the customer receiving the work.',
      ),
      HMBDroplist<Customer>(
        title: 'Bill To customer',
        selectedItem: () => DaoCustomer().getById(_billToId),
        items: (filter) => DaoCustomer().getByFilter(filter),
        format: (value) => value.name,
        onChanged: (value) => setState(() {
          final billToId = value?.id ?? customer?.id;
          if (_billToId != billToId) {
            _billingContactId = null;
            _useCurrentBillingDefaults = true;
          }
          _billToId = billToId;
        }),
      ),
      HMBDroplist<Contact>(
        key: ValueKey('billing-contact-$_billToId'),
        title: 'Billing Contact (optional)',
        required: false,
        selectedItem: () => DaoContact().getById(_billingContactId),
        items: (filter) async => (await billingContactsForCustomer(_billToId))
            .where(
              (value) => value.fullname.toLowerCase().contains(
                (filter ?? '').toLowerCase(),
              ),
            )
            .toList(),
        format: (value) => value.fullname.trim(),
        onChanged: (value) => setState(() {
          _billingContactId = value?.id;
          _useCurrentBillingDefaults = true;
        }),
      ),
      if (currentEntity?.legacyBillingContactId != null &&
          _billingContactId == null &&
          !_useCurrentBillingDefaults) ...[
        const Text(
          'This job keeps its previous billing recipient until you choose '
          'a new contact, change Bill To, or use the current defaults.',
        ),
        HMBButtonSecondary(
          label: 'Use current defaults',
          hint: 'Use automatic recipient selection when you save',
          onPressed: () => setState(() => _useCurrentBillingDefaults = true),
        ),
      ],
      const Text(
        'Leave the contact blank to use the Bill To customer’s '
        'default billing contact, then a Primary Contact or the only job '
        'contact belonging to that customer. Otherwise invoicing asks '
        'you to select one.',
      ),
      // Retain shared HMB billing-type and rate controls.
      _editor(customer),
    ],
  );

  Future<void> _saveSection() async {
    if (_saving || !validateFormAndRevealErrors(_formKey)) {
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await BlockingUI().runAndWait(
        () => DatabaseHelper.instance.database.transaction((txn) async {
          final latest = await DaoJob().getById(currentEntity!.id, txn);
          if (latest == null) {
            throw StateError('This job no longer exists.');
          }
          _applySection(latest);
          await DaoJob().update(latest, txn);
          return latest;
        }),
      );
      if (mounted) {
        Navigator.pop(context, updated);
      }
    } catch (error) {
      HMBToast.error(error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _applySection(Job job) {
    switch (widget.section!) {
      case JobEditSection.summary:
        job
          ..summary = _summaryController.text.trim()
          ..description = _descriptionController.text;
      case JobEditSection.customer:
        job.customerId = June.getState(SelectedCustomer.new).customerId;
      case JobEditSection.site:
        job.siteId = June.getState(SelectedSite.new).siteId;
      case JobEditSection.billing:
        final rate = Money.tryParse(_hourlyRateController.text, isoCode: 'AUD');
        final fee = Money.tryParse(_bookingFeeController.text, isoCode: 'AUD');
        if (rate == null || fee == null || rate.isNegative || fee.isNegative) {
          throw StateError('Enter valid non-negative rates.');
        }
        if (_useCurrentBillingDefaults) {
          job.legacyBillingContactId = null;
        }
        job
          ..billToCustomerId = _billToId
          ..billingContactId = _billingContactId
          ..billingType = _billingType
          ..hourlyRate = rate
          ..bookingFee = fee;
      case JobEditSection.internalNotes:
        job.internalNotes = _notesController.text;
      case JobEditSection.assumptions:
        job.assumption = _assumptionController.text;
      case JobEditSection.parties ||
          JobEditSection.schedule ||
          JobEditSection.notes ||
          JobEditSection.attachments ||
          JobEditSection.photos:
        throw StateError('This section saves its own records.');
    }
  }

  @override
  Future<Job> forUpdate(Job job) async {
    final latest = (await DaoJob().getById(job.id))!;
    if (widget.section != null) {
      _applySection(latest);
    }
    return latest;
  }

  @override
  Future<Job> forInsert() async => Job.forInsert(
    customerId: June.getState(SelectedCustomer.new).customerId,
    referrerCustomerId: June.getState(SelectedReferrerCustomer.new).customerId,
    summary: _summaryController.text,
    description: _descriptionController.text,
    internalNotes: _notesController.text,
    assumption: _assumptionController.text,
    siteId: June.getState(SelectedSite.new).siteId,
    contactId: June.getState(SelectedContact.new).contactId,
    status: JobStatus.startingStatus,
    hourlyRate: MoneyEx.tryParse(_hourlyRateController.text),
    bookingFee: MoneyEx.tryParse(_bookingFeeController.text),
    billingType: _billingType,
    billingContactId: June.getState(JobBillingContact.new).contactId,
    referrerContactId: June.getState(SelectedReferrerContact.new).contactId,
    tenantContactId: June.getState(SelectedTenantContact.new).contactId,
    billingParty: June.getState(SelectedBillingParty.new).billingParty,
  );

  @override
  Future<void> postSave(Job entity) async {
    currentEntity = entity;
    if (mounted) {
      setState(() => _revision++);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _summaryController,
      _descriptionController,
      _notesController,
      _assumptionController,
      _hourlyRateController,
      _bookingFeeController,
    ]) {
      controller.dispose();
    }
    for (final node in [
      _summaryFocusNode,
      _descriptionFocusNode,
      _notesFocusNode,
      _assumptionFocusNode,
      _hourlyRateFocusNode,
      _bookingFeeFocusNode,
    ]) {
      node.dispose();
    }
    super.dispose();
  }
}
