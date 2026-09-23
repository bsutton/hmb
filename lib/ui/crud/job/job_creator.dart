// ignore_for_file: async_return_with_no_await

import 'dart:async';
import 'dart:math' as math;

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:strings/strings.dart';

import '../../../api/chat_gpt/customer_extract_api_client.dart';
import '../../../api/chat_gpt/job_assist_api_client.dart';
import '../../../api/chat_gpt/open_ai_attachment.dart';
import '../../../dao/dao.g.dart';
import '../../../dao/dao_contact_role.dart';
import '../../../dao/dao_job_party.dart';
import '../../../dao/job_billing_contact.dart';
import '../../../entity/contact_role.dart';
import '../../../entity/entity.g.dart';
import '../../../entity/job_party.dart';
import '../../../util/dart/money_ex.dart';
import '../../../util/dart/parse/parse_customer.dart';
import '../../../util/dart/parse/parsed_job_parties.dart';
import '../../dialog/source_context.dart';
import '../../test_keys.dart';
import '../../widgets/fields/hmb_email_field.dart';
import '../../widgets/fields/hmb_money_editing_controller.dart';
import '../../widgets/fields/hmb_money_field.dart';
import '../../widgets/fields/hmb_phone_field.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/select.g.dart';
import '../../widgets/widgets.g.dart';
import '../customer/customer_paste_panel.dart';
import 'job_creation_email_source.dart';
import 'job_parties_screen.dart';
import 'post_job_todo_prompt.dart';

class JobCreator extends StatefulWidget {
  final String? initialMessage;
  final JobCreationEmailSource? emailSource;

  const JobCreator({super.key, this.initialMessage, this.emailSource});

  static Future<Job?> show(
    BuildContext context, {
    String? initialMessage,
    JobCreationEmailSource? emailSource,
  }) async {
    if (!context.mounted) {
      return null;
    }
    return showDialog<Job>(
      context: context,
      builder: (context) =>
          JobCreator(initialMessage: initialMessage, emailSource: emailSource),
    );
  }

  @override
  State<JobCreator> createState() => _JobCreatorState();
}

class _JobCreatorState extends DeferredState<JobCreator> {
  final _firstName = TextEditingController();
  final _surname = TextEditingController();
  final _mobileNo = TextEditingController();
  final _email = TextEditingController();
  final _customerName = TextEditingController();
  final _addressLine1 = TextEditingController();
  final _addressLine2 = TextEditingController();
  final _suburb = TextEditingController();
  final _state = TextEditingController();
  final _postcode = TextEditingController();
  final List<TextEditingController> _siteAddress = List.generate(
    5,
    (_) => TextEditingController(),
  );
  var _sameSiteAddress = true;
  final _jobSummary = TextEditingController();
  final _jobDescription = TextEditingController();
  final _existingContactFilter = TextEditingController();
  final _existingSiteFilter = TextEditingController();
  final _taskControllers = <TextEditingController>[];
  late String _pasteMessage;
  BillingType _selectedBillingType = BillingType.timeAndMaterial;

  final _hourlyRate = HMBMoneyEditingController();
  final _bookingFee = HMBMoneyEditingController();
  Customer? _billToCustomer;
  Contact? _billingContact;
  var _primaryRemoved = false;
  var _referrerRemoved = false;
  final _additionalParties = <JobParty>[];
  ParsedJobParties? _partySuggestions;
  final _pendingContacts = <(Contact, Customer?)>[];
  final _reviewedSuggestions = <ParsedJobParty>{};
  var _nextPartyId = -10;

  var _creating = false;
  var _extracting = false;
  var _aiConfigured = false;
  Customer? _selectedCustomer;
  Customer? _selectedReferrerCustomer;
  List<_CustomerMatch> _matches = [];
  List<Contact> _existingContacts = [];
  List<Site> _existingSites = [];
  Contact? _selectedExistingContact;
  Contact? _selectedReferrerContact;
  Contact? _selectedPrimaryContact;
  Contact? _draftPrimaryContact;
  Site? _selectedExistingSite;
  late final List<WizardStep> _steps;
  late final _CustomerStep _customerStep;

  @override
  void initState() {
    super.initState();
    _pasteMessage = widget.emailSource?.aiText ?? widget.initialMessage ?? '';
    _customerStep = _CustomerStep(this);
    _steps = [
      _ExtractAndMatchStep(this),
      _customerStep,
      _ContactStep(this),
      _AddressStep(this),
      _PartiesStep(this),
      _BillingStep(this),
      _JobStep(this),
    ];
  }

  @override
  Future<void> asyncInitState() async {
    await _loadAiConfigured();
    final system = await DaoSystem().get();
    _hourlyRate.money = system.defaultHourlyRate ?? MoneyEx.zero;
    _bookingFee.money = system.defaultBookingFee ?? MoneyEx.zero;
    if (widget.emailSource != null) {
      await _seedFromEmail(widget.emailSource!);
    }
  }

  Future<void> _loadAiConfigured() async {
    final credentials = await DaoSystem().getOpenAiCredentials();
    if (!mounted) {
      return;
    }
    setState(() {
      _aiConfigured = (credentials.apiKey?.trim() ?? '').isNotEmpty;
    });
  }

  Future<void> _seedFromEmail(JobCreationEmailSource source) async {
    final parsed = await ParsedCustomer.parse(source.aiText);
    final nameParts = source.senderName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (source.senderEmail.isNotEmpty) {
      parsed.email = source.senderEmail;
    }
    if (nameParts.isNotEmpty) {
      parsed
        ..firstname = nameParts.first
        ..surname = nameParts.skip(1).join(' ')
        ..customerName = source.senderName.trim();
    }
    if (!mounted) {
      return;
    }
    _email.text = parsed.email;
    _mobileNo.text = parsed.mobile;
    _firstName.text = parsed.firstname;
    _surname.text = parsed.surname;
    _customerName.text = parsed.customerName;
    _addressLine1.text = parsed.address.street;
    _suburb.text = parsed.address.city;
    _state.text = parsed.address.state;
    _postcode.text = parsed.address.postalCode;
    await _loadMatches(parsed);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _surname.dispose();
    _mobileNo.dispose();
    _email.dispose();
    _customerName.dispose();
    _addressLine1.dispose();
    _addressLine2.dispose();
    _suburb.dispose();
    _state.dispose();
    _postcode.dispose();
    for (final controller in _siteAddress) {
      controller.dispose();
    }
    _hourlyRate.dispose();
    _bookingFee.dispose();
    _jobSummary.dispose();
    _jobDescription.dispose();
    _existingContactFilter.dispose();
    _existingSiteFilter.dispose();
    for (final controller in _taskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    waitingBuilder: (_) => const SizedBox.shrink(),
    errorBuilder: (_, error) => const Text('Could not load the job wizard.'),
    builder: _buildWizard,
  );

  Widget _buildWizard(BuildContext context) {
    final theme = Theme.of(context);
    final surface =
        theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface;

    return AlertDialog(
      insetPadding: const EdgeInsets.all(8),
      contentPadding: const EdgeInsets.all(8),
      title: Row(
        children: [
          const Expanded(child: Text('Create Job Wizard')),
          if (widget.emailSource != null)
            HMBButton.smallWithIcon(
              label: 'Source email',
              hint: 'View and copy details from the source email',
              icon: const Icon(Icons.email_outlined),
              onPressed: _showSourceEmail,
            ),
        ],
      ),
      content: Theme(
        data: theme.copyWith(
          canvasColor: surface,
          cardColor: surface,
          scaffoldBackgroundColor: surface,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.35),
            ),
          ),
          child: SizedBox(
            width: math.min(MediaQuery.of(context).size.width * 0.92, 980),
            height: math.min(MediaQuery.of(context).size.height * 0.82, 760),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Wizard(
                initialSteps: _steps,
                onFinished: _onWizardFinished,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Tasks'),
      ..._taskControllers.asMap().entries.map((entry) {
        final index = entry.key;
        final controller = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  decoration: InputDecoration(labelText: 'Task ${index + 1}'),
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _taskControllers.removeAt(index).dispose();
                }),
                icon: const Icon(Icons.delete),
              ),
            ],
          ),
        );
      }),
      TextButton.icon(
        onPressed: () =>
            setState(() => _taskControllers.add(TextEditingController())),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
    ],
  );

  void _showSourceEmail() {
    final source = widget.emailSource;
    if (source == null) {
      return;
    }
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(source.subject.isEmpty ? 'Source email' : source.subject),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(child: SelectableText(source.aiText)),
          ),
          actions: [
            HMBButton(
              label: 'Copy subject',
              hint: 'Copy the email subject',
              onPressed: () {
                unawaited(
                  Clipboard.setData(ClipboardData(text: source.subject)),
                );
                HMBToast.info('Email subject copied');
              },
            ),
            HMBButton(
              label: 'Copy body',
              hint: 'Copy the email body',
              onPressed: () {
                unawaited(Clipboard.setData(ClipboardData(text: source.body)));
                HMBToast.info('Email body copied');
              },
            ),
            HMBButton(
              label: 'Use subject',
              hint: 'Use the email subject as the job summary',
              onPressed: () {
                setState(() => _jobSummary.text = source.subject);
                HMBToast.info('Job summary updated');
              },
            ),
            HMBButton(
              label: 'Replace description',
              hint: 'Replace the job description with the email body',
              onPressed: () {
                setState(() => _jobDescription.text = source.body);
                HMBToast.info('Job description updated');
              },
            ),
            HMBButton(
              label: 'Append description',
              hint: 'Append the email body to the job description',
              onPressed: () {
                final current = _jobDescription.text.trim();
                setState(() {
                  _jobDescription.text = current.isEmpty
                      ? source.body
                      : '$current\n\n${source.body}';
                });
                HMBToast.info('Email body appended');
              },
            ),
            HMBButton(
              label: 'Close',
              hint: 'Return to job creation',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingCustomerPicker() => RadioGroup<Customer?>(
    groupValue: _selectedCustomer,
    onChanged: (value) {
      setState(() {
        if (_billToCustomer == null && _selectedCustomer?.id != value?.id) {
          _billingContact = null;
        }
        _primaryRemoved = false;
        _selectedCustomer = value;
        if (value != null) {
          _customerName.text = value.name;
          unawaited(_loadExistingCustomerDetails(value));
        } else {
          _existingContacts = [];
          _existingSites = [];
          _selectedExistingContact = null;
          _selectedPrimaryContact = null;
          _draftPrimaryContact = null;
          _selectedExistingSite = null;
        }
      });
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _matches.isEmpty
              ? 'No existing matches found'
              : 'Existing customer matches',
        ),
        ..._matches.map(
          (match) => RadioListTile<Customer?>(
            title: Text(match.customer.name),
            subtitle: Text(match.contact?.emailAddress ?? 'No contact'),
            value: match.customer,
          ),
        ),
        const RadioListTile<Customer?>(
          title: Text('Create new customer'),
          value: null,
        ),
      ],
    ),
  );

  Widget _buildCustomerSearchPicker() => HMBDroplist<Customer>(
    title: 'Find Existing Customer',
    required: false,
    selectedItem: () => Future.value(_selectedCustomer),
    items: (filter) => DaoCustomer().getByFilter(filter),
    format: (customer) => customer.name,
    onChanged: (customer) {
      setState(() {
        if (_billToCustomer == null && _selectedCustomer?.id != customer?.id) {
          _billingContact = null;
        }
        _primaryRemoved = false;
        _selectedCustomer = customer;
        if (customer != null) {
          _customerName.text = customer.name;
          unawaited(_loadExistingCustomerDetails(customer));
        } else {
          _existingContacts = [];
          _existingSites = [];
          _selectedExistingContact = null;
          _selectedPrimaryContact = null;
          _draftPrimaryContact = null;
          _selectedExistingSite = null;
        }
      });
    },
  );

  Future<void> _loadExistingCustomerDetails(Customer customer) async {
    final daoContact = DaoContact();
    final daoSite = DaoSite();
    final contacts = await daoContact.getByCustomer(customer.id);
    final sites = await daoSite.getByCustomer(customer.id);
    final primarySite = await daoSite.getPrimaryForCustomer(customer.id);
    contacts.sort(
      (a, b) => _displayName(
        a,
      ).toLowerCase().compareTo(_displayName(b).toLowerCase()),
    );
    if (!mounted || _selectedCustomer?.id != customer.id) {
      return;
    }
    setState(() {
      _existingContacts = contacts;
      _existingSites = sites;
      _selectedExistingContact = _pickBestMatchingContact(contacts);
      _selectedPrimaryContact ??= _selectedExistingContact;
      _selectedExistingSite = primarySite;
    });
  }

  Future<void> _loadReferrerContacts(Customer? customer) async {
    if (customer == null) {
      setState(() {
        _selectedReferrerContact = null;
      });
      return;
    }

    final contacts = await DaoContact().getByCustomer(customer.id);
    if (!mounted || _selectedReferrerCustomer?.id != customer.id) {
      return;
    }
    setState(() {
      _selectedReferrerContact = contacts.isEmpty ? null : contacts.first;
    });
  }

  List<JobParty> _parties() => [
    if (_resolvedPrimaryContact() case final contact?)
      JobParty(
        id: -1,
        contact: contact,
        role: const ContactRole(
          id: ContactRole.primary,
          name: 'Primary Contact',
          builtin: true,
        ),
      ),
    if (!_referrerRemoved && _selectedReferrerContact != null)
      JobParty(
        id: -2,
        contact: _selectedReferrerContact!,
        role: const ContactRole(
          id: ContactRole.referrer,
          name: 'Referrer',
          builtin: true,
        ),
      ),
    if (_billingContact case final contact?)
      JobParty(
        id: -3,
        contact: contact,
        role: const ContactRole(
          id: ContactRole.billing,
          name: 'Billing Contact',
          builtin: true,
        ),
      ),
    ..._additionalParties,
  ];

  Future<List<Contact>> _billingContacts() async => [
    ...await billingContactsForCustomer(
      _billToCustomer?.id ?? _selectedCustomer?.id,
    ),
    if (_billToCustomer == null) ...[?_draftPrimaryContactForCurrentFields()],
    for (final pending in _pendingContacts)
      if (pending.$2?.id == (_billToCustomer?.id ?? _selectedCustomer?.id))
        pending.$1,
  ];

  void _removeParty(JobParty party) {
    setState(() {
      switch (party.id) {
        case -1:
          _primaryRemoved = true;
        case -2:
          _referrerRemoved = true;
        case -3:
          _billingContact = null;
        default:
          _additionalParties.removeWhere((other) => other.id == party.id);
      }
    });
  }

  Future<void> _editParty([JobParty? party]) async {
    final draft = _draftPrimaryContactForCurrentFields();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JobPartyAssignmentEditor(
          customerId: _selectedCustomer?.id,
          billToCustomerId: _billToCustomer?.id ?? _selectedCustomer?.id,
          parties: _parties(),
          createContact: _createDraftPartyContact,
          party: party,
          draftContacts: [?draft, ..._pendingContacts.map((entry) => entry.$1)],
          draftBillingContacts: [
            if (_billToCustomer == null) ...[?draft],
            for (final pending in _pendingContacts)
              if (pending.$2?.id ==
                  (_billToCustomer?.id ?? _selectedCustomer?.id))
                pending.$1,
          ],
          onSave: (contact, role, {required replace}) async {
            if (party != null) {
              _removeParty(party);
            }
            setState(() {
              switch (role.id) {
                case ContactRole.primary:
                  _primaryRemoved = false;
                  _selectedPrimaryContact = contact;
                case ContactRole.billing:
                  _billingContact = contact;
                default:
                  _additionalParties.add(
                    JobParty(id: _nextPartyId--, contact: contact, role: role),
                  );
              }
            });
          },
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<Contact?> _createDraftPartyContact({required bool billing}) async {
    final form = GlobalKey<FormState>();
    final firstName = TextEditingController();
    final surname = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final owner = billing
        ? _billToCustomer ?? _selectedCustomer
        : _selectedCustomer;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add contact'),
          scrollable: true,
          content: Form(
            key: form,
            child: HMBColumn(
              children: [
                Text('Customer: ${owner?.name ?? _customerName.text}'),
                HMBTextField(controller: firstName, labelText: 'First Name'),
                HMBTextField(controller: surname, labelText: 'Surname'),
                HMBEmailField(controller: email, labelText: 'Email'),
                HMBPhoneField(
                  controller: phone,
                  labelText: 'Phone',
                  sourceContext: SourceContext(customer: owner),
                ),
              ],
            ),
          ),
          actions: [
            HMBCancelButton(onPressed: () => Navigator.pop(context, false)),
            HMBButtonPrimary(
              label: 'Use contact',
              hint: 'Keep this contact in the draft job',
              onPressed: () {
                if (!form.currentState!.validate()) {
                  return;
                }
                if (firstName.text.trim().isEmpty &&
                    surname.text.trim().isEmpty) {
                  HMBToast.error('Enter a contact name.');
                  return;
                }
                Navigator.pop(context, true);
              },
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return null;
      }
      final contact = Contact.forInsert(
        firstName: firstName.text.trim(),
        surname: surname.text.trim(),
        emailAddress: email.text.trim(),
        mobileNumber: phone.text.trim(),
        landLine: '',
        officeNumber: '',
      )..id = _nextPartyId--;
      _pendingContacts.add((contact, owner));
      return contact;
    } finally {
      firstName.dispose();
      surname.dispose();
      email.dispose();
      phone.dispose();
    }
  }

  Future<Customer?> _exactCustomer(String name) async {
    if (name.trim().isEmpty) {
      return null;
    }
    final matches = (await DaoCustomer().getByFilter(name))
        .where((customer) => _normalize(customer.name) == _normalize(name))
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  Future<void> _reviewSuggestedBusiness({required bool billing}) async {
    final suggestions = _partySuggestions!;
    final name = billing
        ? suggestions.billToCustomer
        : suggestions.referringCustomer;
    var selected = await BlockingUI().runAndWait(() => _exactCustomer(name));
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          billing ? 'Review Bill To suggestion' : 'Review referring business',
        ),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name),
            Text(
              billing
                  ? suggestions.billingEvidence
                  : suggestions.referralEvidence,
            ),
            const SizedBox(height: 12),
            HMBDroplist<Customer>(
              title: 'Customer',
              selectedItem: () async => selected,
              items: (filter) => DaoCustomer().getByFilter(filter),
              format: (customer) => customer.name,
              onChanged: (customer) => selected = customer,
            ),
          ],
        ),
        actions: [
          HMBCancelButton(onPressed: () => Navigator.pop(context, false)),
          HMBButtonPrimary(
            label: 'Use customer',
            hint: 'Confirm this customer',
            onPressed: () {
              if (selected != null) {
                Navigator.pop(context, true);
              } else {
                HMBToast.error('Select a customer first.');
              }
            },
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    if (billing) {
      setState(() {
        _billToCustomer = selected;
        _billingContact = null;
      });
    } else {
      setState(() {
        _selectedReferrerCustomer = selected;
        _referrerRemoved = false;
      });
      await _loadReferrerContacts(selected);
    }
  }

  Future<void> _reviewSuggestedParty(ParsedJobParty suggestion) async {
    final candidates = await BlockingUI().runAndWait(() async {
      final all = await DaoContact().getAll();
      return all
          .where(
            (contact) =>
                (suggestion.email.isNotEmpty &&
                    _normalize(contact.emailAddress) ==
                        _normalize(suggestion.email)) ||
                (suggestion.phone.isNotEmpty &&
                    _normalizedDigits(contact.bestPhone) ==
                        _normalizedDigits(suggestion.phone)),
          )
          .toList();
    });
    final roles = await DaoContactRole().getAll();
    final role = roles
        .where((role) => _normalize(role.name) == _normalize(suggestion.role))
        .firstOrNull;
    if (!mounted) {
      return;
    }
    Contact contact;
    (Contact, Customer?)? pending;
    if (candidates.length == 1) {
      contact = candidates.single;
    } else {
      var owner = await _exactCustomer(suggestion.customerName);
      owner ??= role?.id == ContactRole.billing
          ? _billToCustomer ?? _selectedCustomer
          : _selectedCustomer;
      if (!mounted) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Review new contact'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(suggestion.name),
              Text(suggestion.email),
              Text(suggestion.phone),
              if (suggestion.customerName.isNotEmpty)
                Text('Suggested customer: ${suggestion.customerName}'),
              const Text(
                'Choose the customer this contact belongs to. '
                'Leave blank to use the job customer. '
                'No contact is saved until '
                'you finish the wizard.',
              ),
              HMBDroplist<Customer>(
                title: 'Contact’s customer',
                required: false,
                selectedItem: () async => owner,
                items: (filter) => DaoCustomer().getByFilter(filter),
                format: (customer) => customer.name,
                onChanged: (customer) => owner = customer,
              ),
            ],
          ),
          actions: [
            HMBCancelButton(onPressed: () => Navigator.pop(context, false)),
            HMBButtonPrimary(
              label: 'Review role',
              hint: 'Choose a role for this contact',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      contact = Contact.forInsert(
        firstName: suggestion.firstName,
        surname: suggestion.surname,
        mobileNumber: suggestion.phone,
        emailAddress: suggestion.email,
        landLine: '',
        officeNumber: '',
      )..id = _nextPartyId--;
      pending = (contact, owner);
      _pendingContacts.add(pending);
    }
    await _editParty(
      JobParty(
        id: _nextPartyId--,
        contact: contact,
        role:
            role ??
            const ContactRole(id: 0, name: 'Choose a role', builtin: false),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      if (_parties().any((party) => identical(party.contact, contact))) {
        _reviewedSuggestions.add(suggestion);
      } else if (pending != null) {
        _pendingContacts.remove(pending);
      }
    });
  }

  Widget _suggestedParties() => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Suggested parties — review before assigning'),
      if (_partySuggestions!.referringCustomer.isNotEmpty)
        ListTile(
          title: Text(_partySuggestions!.referringCustomer),
          subtitle: Text(
            'Referring business: ${_partySuggestions!.referralEvidence}',
          ),
          trailing: HMBActionLink(
            label: 'Review',
            onPressed: () => _reviewSuggestedBusiness(billing: false),
          ),
        ),
      for (final suggestion in _partySuggestions!.contacts)
        if (!_reviewedSuggestions.contains(suggestion))
          ListTile(
            title: Text(
              suggestion.name.isEmpty ? suggestion.email : suggestion.name,
            ),
            subtitle: Text(
              '${suggestion.role} · ${suggestion.customerName}\n'
              '${suggestion.email} ${suggestion.phone}\n${suggestion.evidence}',
            ),
            trailing: HMBActionLink(
              label: 'Review',
              onPressed: () => _reviewSuggestedParty(suggestion),
            ),
          ),
    ],
  );

  Widget _buildParties() => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Assign contacts and their roles for this job. '
        'These assignments are saved when you finish the wizard.',
      ),
      if (_partySuggestions != null) _suggestedParties(),
      HMBDroplist<Customer>(
        title: 'Referring business',
        fieldKey: TestKeys.jobCreatorReferredBySelector,
        required: false,
        selectedItem: () async => _selectedReferrerCustomer,
        items: (filter) => DaoCustomer().getByFilter(filter),
        format: (customer) => customer.name,
        onChanged: (customer) async {
          setState(() {
            _selectedReferrerCustomer = customer;
            _referrerRemoved = false;
          });
          await _loadReferrerContacts(customer);
        },
      ),
      for (final party in _parties())
        Surface(
          padding: EdgeInsets.zero,
          child: ListTile(
            title: Text(party.contact.fullname.trim()),
            subtitle: Text(party.role.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit ${party.role.name}',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editParty(party),
                ),
                IconButton(
                  tooltip: 'Remove ${party.role.name}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeParty(party),
                ),
              ],
            ),
          ),
        ),
      HMBButtonPrimary(
        label: 'Add party',
        hint: 'Assign a contact and role',
        onPressed: _editParty,
      ),
    ],
  );

  Widget _buildBilling() => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Choose whose account receives the bill. This defaults to '
        'the job customer and can be different from the customer '
        'receiving the work.',
      ),
      if (_partySuggestions?.billToCustomer.isNotEmpty ?? false)
        ListTile(
          title: Text(
            'Suggested Bill To: ${_partySuggestions!.billToCustomer}',
          ),
          subtitle: Text(_partySuggestions!.billingEvidence),
          trailing: HMBActionLink(
            label: 'Review',
            onPressed: () => _reviewSuggestedBusiness(billing: true),
          ),
        ),
      HMBDroplist<Customer>(
        title: 'Bill To customer',
        required: false,
        selectedItem: () async => _billToCustomer ?? _selectedCustomer,
        items: (filter) => DaoCustomer().getByFilter(filter),
        format: (customer) => customer.name,
        onChanged: (customer) => setState(() {
          _billToCustomer = customer;
          _billingContact = null;
        }),
      ),
      if (_billToCustomer == null && _selectedCustomer == null)
        Text('Bill To defaults to the new customer: ${_customerName.text}'),
      HMBDroplist<Contact>(
        key: ValueKey(
          'billing-${_billToCustomer?.id}-${_selectedCustomer?.id}',
        ),
        title: 'Billing Contact (optional)',
        required: false,
        selectedItem: () async => _billingContact,
        items: (filter) async => (await _billingContacts())
            .where(
              (contact) => contact.fullname.toLowerCase().contains(
                (filter ?? '').toLowerCase(),
              ),
            )
            .toList(),
        format: (contact) => contact.fullname.trim(),
        onChanged: (contact) => setState(() => _billingContact = contact),
      ),
      const Text(
        'Leave the contact blank to use the Bill To customer’s '
        'default billing contact, then a Primary Contact or the only job '
        'contact belonging to that customer. Otherwise invoicing asks '
        'you to select one.',
      ),
      HMBDroplist<BillingType>(
        title: 'Billing Type',
        fieldKey: TestKeys.jobCreatorBillingTypeSelector,
        selectedItem: () async => _selectedBillingType,
        items: (_) async => BillingType.values,
        format: (type) => type.display,
        onChanged: (type) => setState(() {
          if (type != null) {
            _selectedBillingType = type;
          }
        }),
      ),
      HMBMoneyField(
        controller: _hourlyRate,
        labelText: 'Hourly Rate',
        fieldName: 'Hourly Rate',
        nonZero: false,
      ),
      HMBMoneyField(
        controller: _bookingFee,
        labelText: 'Booking Fee',
        fieldName: 'Booking Fee',
        nonZero: false,
      ),
    ],
  );

  Contact? _draftPrimaryContactForCurrentFields() {
    if (_selectedExistingContact != null) {
      return null;
    }

    final hasDetails =
        _firstName.text.trim().isNotEmpty ||
        _surname.text.trim().isNotEmpty ||
        _mobileNo.text.trim().isNotEmpty ||
        _email.text.trim().isNotEmpty;
    if (!hasDetails) {
      _draftPrimaryContact = null;
      return null;
    }

    final draft =
        (_draftPrimaryContact ??= Contact.forInsert(
            firstName: _firstName.text,
            surname: _surname.text,
            mobileNumber: _mobileNo.text,
            landLine: '',
            officeNumber: '',
            emailAddress: _email.text,
          ))
          ..firstName = _firstName.text
          ..surname = _surname.text
          ..mobileNumber = _mobileNo.text
          ..emailAddress = _email.text;
    return draft;
  }

  Contact? _resolvedPrimaryContact() => _primaryRemoved
      ? null
      : _selectedPrimaryContact == _draftPrimaryContact
      ? _draftPrimaryContactForCurrentFields()
      : _selectedPrimaryContact ??
            _selectedExistingContact ??
            _draftPrimaryContactForCurrentFields();

  Contact? _pickBestMatchingContact(List<Contact> contacts) {
    if (contacts.isEmpty) {
      return null;
    }

    final normalizedEmail = _normalize(_email.text);
    if (normalizedEmail.isNotEmpty) {
      final emailMatch = contacts.firstWhere(
        (contact) => _normalize(contact.emailAddress) == normalizedEmail,
        orElse: () => contacts.first,
      );
      if (_normalize(emailMatch.emailAddress) == normalizedEmail) {
        return emailMatch;
      }
    }

    final normalizedMobile = _normalizedDigits(_mobileNo.text);
    if (normalizedMobile.isNotEmpty) {
      final mobileMatch = contacts.firstWhere(
        (contact) =>
            _normalizedDigits(contact.mobileNumber) == normalizedMobile,
        orElse: () => contacts.first,
      );
      if (_normalizedDigits(mobileMatch.mobileNumber) == normalizedMobile) {
        return mobileMatch;
      }
    }

    final normalizedFirst = _normalize(_firstName.text);
    final normalizedSurname = _normalize(_surname.text);
    if (normalizedFirst.isNotEmpty || normalizedSurname.isNotEmpty) {
      final nameMatch = contacts.firstWhere(
        (contact) =>
            _normalize(contact.firstName) == normalizedFirst &&
            _normalize(contact.surname) == normalizedSurname,
        orElse: () => contacts.first,
      );
      final firstMatches =
          _normalize(nameMatch.firstName) == normalizedFirst &&
          normalizedFirst.isNotEmpty;
      final surnameMatches =
          _normalize(nameMatch.surname) == normalizedSurname &&
          normalizedSurname.isNotEmpty;
      if (firstMatches || surnameMatches) {
        return nameMatch;
      }
    }

    return contacts.first;
  }

  String _normalize(String value) => value.trim().toLowerCase();

  String _normalizedDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

  String _displayContact(Contact contact) {
    final name = '${contact.firstName} ${contact.surname}'.trim();
    if (name.isNotEmpty) {
      return name;
    }
    if (contact.emailAddress.isNotEmpty) {
      return contact.emailAddress;
    }
    if (contact.mobileNumber.isNotEmpty) {
      return contact.mobileNumber;
    }
    return 'New contact';
  }

  String _displayName(Contact contact) => _displayContact(contact);

  List<Contact> _filteredExistingContacts() {
    final filter = _normalize(_existingContactFilter.text);
    if (filter.isEmpty) {
      return _existingContacts;
    }
    return _existingContacts.where((contact) {
      final name = _displayName(contact).toLowerCase();
      final email = contact.emailAddress.toLowerCase();
      final mobile = contact.mobileNumber.toLowerCase();
      return name.contains(filter) ||
          email.contains(filter) ||
          mobile.contains(filter);
    }).toList();
  }

  List<Site> _filteredExistingSites() {
    final filter = _normalize(_existingSiteFilter.text);
    if (filter.isEmpty) {
      return _existingSites;
    }
    return _existingSites.where((site) {
      final line1 = site.addressLine1.toLowerCase();
      final line2 = site.addressLine2.toLowerCase();
      final suburb = site.suburb.toLowerCase();
      final state = site.state.toLowerCase();
      final postcode = site.postcode.toLowerCase();
      return line1.contains(filter) ||
          line2.contains(filter) ||
          suburb.contains(filter) ||
          state.contains(filter) ||
          postcode.contains(filter);
    }).toList();
  }

  Future<bool> _onExtract(String text) async {
    if (_extracting) {
      return false;
    }
    if (Strings.isBlank(text)) {
      HMBToast.info('Paste a message to extract, or skip extraction.');
      return false;
    }

    final credentials = await DaoSystem().getOpenAiCredentials();
    final apiKey = credentials.apiKey?.trim() ?? '';
    if (apiKey.isEmpty) {
      _showAiRequiredMessage();
      return false;
    }

    var extractedSuccessfully = false;
    setState(() => _extracting = true);
    try {
      await BlockingUI().runAndWait(() async {
        final attachments =
            widget.emailSource?.attachments
                .where(
                  (attachment) =>
                      attachment.data != null &&
                      attachment.data!.length <= maxOpenAiAttachmentBytes,
                )
                .map(
                  (attachment) => OpenAiAttachment(
                    filename: attachment.filename,
                    mimeType: attachment.mimeType,
                    data: attachment.data!,
                  ),
                )
                .toList() ??
            const <OpenAiAttachment>[];
        final parsedCustomer = await CustomerExtractApiClient().extract(
          text,
          attachments: attachments,
          forJob: true,
        );
        if (parsedCustomer == null) {
          HMBToast.error('AI extraction failed. Check ChatGPT settings.');
          return;
        }

        _email.text = parsedCustomer.email;
        _mobileNo.text = parsedCustomer.mobile;

        _firstName.text = parsedCustomer.firstname;
        _surname.text = parsedCustomer.surname;
        final address = parsedCustomer.address;
        _addressLine1.text = address.street;
        _suburb.text = address.city;
        _state.text = address.state;
        _postcode.text = address.postalCode;

        _customerName.text = parsedCustomer.customerName.isEmpty
            ? '${_firstName.text} ${_surname.text}'.trim()
            : parsedCustomer.customerName;

        await _generateSummaryAndTasks(text, attachments: attachments);

        await _loadMatches(parsedCustomer);
        _partySuggestions = parsedCustomer.jobParties;
        extractedSuccessfully = true;
      }, label: 'Extracting job details');

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      HMBToast.error('AI extraction failed: $e');
    } finally {
      if (mounted) {
        setState(() => _extracting = false);
      }
    }
    return extractedSuccessfully;
  }

  void _showAiRequiredMessage() {
    HMBToast.info(
      'AI extraction requires an OpenAI API key in Settings | Integrations | '
      'ChatGPT. You can skip extraction and enter the job details manually.',
    );
  }

  Future<void> _generateSummaryAndTasks(
    String text, {
    List<OpenAiAttachment> attachments = const [],
  }) async {
    if (Strings.isBlank(text)) {
      return;
    }

    final client = JobAssistApiClient();
    final result = await client.analyzeDescription(
      text,
      attachments: attachments,
    );
    if (result == null) {
      return;
    }
    if (Strings.isBlank(_jobSummary.text)) {
      _jobSummary.text = result.summary;
    }
    if (Strings.isBlank(_jobDescription.text) &&
        Strings.isNotBlank(result.description)) {
      _jobDescription.text = result.description;
    } else if (Strings.isBlank(_jobDescription.text)) {
      _jobDescription.text = text;
    }
    if (_taskControllers.isEmpty) {
      for (final task in result.tasks) {
        _taskControllers.add(TextEditingController(text: task));
      }
    }
  }

  Future<void> _onWizardFinished(WizardCompletionReason reason) async {
    if (!mounted) {
      return;
    }
    switch (reason) {
      case WizardCompletionReason.completed:
        final todoAction = await promptForPostJobTodo(context: context);
        if (todoAction == PostJobTodoAction.cancel) {
          return;
        }
        final job = await BlockingUI().runAndWait(
          _createEntities,
          label: 'Creating job',
        );
        if (job != null && mounted) {
          await createPostJobTodo(
            context: context,
            job: job,
            action: todoAction,
          );
        }
        if (job != null && mounted) {
          Navigator.of(context).pop(job);
        }
        return;
      case WizardCompletionReason.cancelled:
      case WizardCompletionReason.backedOut:
        Navigator.of(context).pop();
        return;
    }
  }

  bool _canCreate() {
    if (_selectedCustomer == null && Strings.isBlank(_customerName.text)) {
      HMBToast.error('Please enter a customer name.');
      return false;
    }
    if (!_sameSiteAddress && _siteAddress.first.text.trim().isEmpty) {
      HMBToast.error(
        'Enter the separate site address or use the customer address.',
      );
      return false;
    }
    if (Strings.isBlank(_jobSummary.text)) {
      HMBToast.error('Please enter a job summary.');
      return false;
    }
    return true;
  }

  Future<void> _loadMatches(ParsedCustomer parsedCustomer) async {
    final matches = <_CustomerMatch>[];
    final seen = <int>{};
    final daoContact = DaoContact();
    final daoCustomer = DaoCustomer();

    if (Strings.isNotBlank(parsedCustomer.email)) {
      final contacts = await daoContact.getByEmail(parsedCustomer.email);
      for (final contact in contacts) {
        final customer = await daoCustomer.getByContact(contact.id);
        if (customer != null && seen.add(customer.id)) {
          matches.add(_CustomerMatch(customer: customer, contact: contact));
        }
      }
    }

    if (Strings.isNotBlank(parsedCustomer.mobile)) {
      final contacts = await daoContact.getByMobile(parsedCustomer.mobile);
      for (final contact in contacts) {
        final customer = await daoCustomer.getByContact(contact.id);
        if (customer != null && seen.add(customer.id)) {
          matches.add(_CustomerMatch(customer: customer, contact: contact));
        }
      }
    }

    final candidateNames = <String>{
      if (Strings.isNotBlank(parsedCustomer.customerName))
        parsedCustomer.customerName.trim(),
      if (Strings.isNotBlank(parsedCustomer.companyName))
        parsedCustomer.companyName.trim(),
    };

    for (final name in candidateNames) {
      final customers = await daoCustomer.getByName(name);
      for (final customer in customers) {
        if (seen.add(customer.id)) {
          matches.add(_CustomerMatch(customer: customer));
        }
      }
    }

    if (!mounted) {
      return;
    }
    matches.sort(
      (a, b) => a.customer.name.toLowerCase().compareTo(
        b.customer.name.toLowerCase(),
      ),
    );
    setState(() {
      _matches = matches;
      if (_selectedCustomer != null &&
          !_matches.any((m) => m.customer.id == _selectedCustomer!.id)) {
        _selectedCustomer = null;
        _existingContacts = [];
        _existingSites = [];
        _selectedExistingContact = null;
        _selectedReferrerContact = null;
        _selectedPrimaryContact = null;
        _draftPrimaryContact = null;
        _selectedExistingSite = null;
      }
    });
  }

  Future<Job?> _createEntities() async {
    if (_creating || !_canCreate()) {
      return null;
    }

    setState(() => _creating = true);
    try {
      final daoCustomer = DaoCustomer();
      final daoContact = DaoContact();
      final daoSite = DaoSite();
      final daoJob = DaoJob();
      final daoTask = DaoTask();
      final daoSystem = DaoSystem();
      final system = await daoSystem.get();
      final defaultProfitMargin = await daoSystem.getDefaultProfitMargin();

      late Customer customer;
      Contact? contact;
      Site? site;
      late Job job;

      await daoCustomer.withTransaction((transaction) async {
        if (_selectedCustomer != null) {
          customer = _selectedCustomer!;
        } else {
          customer = Customer.forInsert(
            name: _customerName.text,
            description: '',
            customerType: CustomerType.residential,
            disbarred: false,
            billingContactId: null,
            hourlyRate: system.defaultHourlyRate ?? MoneyEx.zero,
          );
          await daoCustomer.insert(customer, transaction);
        }
        contact =
            _selectedExistingContact ?? _draftPrimaryContactForCurrentFields();
        if (contact != null && _selectedExistingContact == null) {
          await daoContact.insert(contact!, transaction);
          await DaoContactCustomer().insertJoin(
            contact!,
            customer,
            transaction,
          );
        }

        if (_selectedCustomer != null && _selectedExistingSite != null) {
          site = _selectedExistingSite;
        } else if (!_isAddressEmpty()) {
          site = Site.forInsert(
            addressLine1: _addressLine1.text,
            addressLine2: _addressLine2.text,
            suburb: _suburb.text,
            postcode: _postcode.text,
            state: _state.text,
            accessDetails: null,
          );
          await daoSite.insert(site!, transaction);
          await DaoSiteCustomer().insertJoin(site!, customer, transaction);
          if (_selectedCustomer == null) {
            await DaoSiteCustomer().setAsPrimary(site!, customer, transaction);
          }
        }

        if (!_sameSiteAddress) {
          site = Site.forInsert(
            addressLine1: _siteAddress[0].text.trim(),
            addressLine2: _siteAddress[1].text.trim(),
            suburb: _siteAddress[2].text.trim(),
            state: _siteAddress[3].text.trim(),
            postcode: _siteAddress[4].text.trim(),
            accessDetails: null,
          );
          await daoSite.insert(site!, transaction);
          await DaoSiteCustomer().insertJoin(site!, customer, transaction);
        }

        if (customer.billingContactId == null && contact != null) {
          final customer2 = customer.copyWith(billingContactId: contact!.id);
          await daoCustomer.update(customer2, transaction);
        }

        final usedContacts = _parties().map((party) => party.contact).toList();
        for (final pending in _pendingContacts) {
          if (!usedContacts.any((used) => identical(used, pending.$1))) {
            continue;
          }
          await daoContact.insert(pending.$1, transaction);
          await DaoContactCustomer().insertJoin(
            pending.$1,
            pending.$2 ?? customer,
            transaction,
          );
        }
        if (_billingContact != null &&
            !(await billingContactsForCustomer(
              _billToCustomer?.id ?? customer.id,
              transaction,
            )).any((candidate) => candidate.id == _billingContact!.id)) {
          throw StateError(
            'Choose a billing contact belonging to the Bill To customer.',
          );
        }
        final primaryContact = _resolvedPrimaryContact();
        job = Job.forInsert(
          customerId: customer.id,
          referrerCustomerId: _selectedReferrerCustomer?.id,
          summary: _jobSummary.text,
          description: _jobDescription.text,
          siteId: site?.id,
          contactId: primaryContact?.id,
          status: JobStatus.prospecting,
          billingType: _selectedBillingType,
          hourlyRate: _hourlyRate.money ?? MoneyEx.zero,
          bookingFee: _bookingFee.money ?? MoneyEx.zero,
          estimateMargin: defaultProfitMargin,
          billToCustomerId: _billToCustomer?.id,
          billingContactId: _billingContact?.id,
          referrerContactId: _referrerRemoved
              ? null
              : _selectedReferrerContact?.id,
        );
        await daoJob.insert(job, transaction);
        for (final party in _additionalParties) {
          await DaoJobParty().save(
            jobId: job.id,
            contactId: party.contact.id,
            roleId: party.role.id,
            transaction: transaction,
          );
        }
        job = (await daoJob.getById(job.id, transaction))!;

        final emailSource = widget.emailSource;
        if (emailSource != null) {
          await DaoJobSourceEmail().insert(
            JobSourceEmail.forInsert(
              jobId: job.id,
              accountEmail: emailSource.accountEmail,
              messageId: emailSource.messageId,
              threadId: emailSource.threadId,
              senderEmail: emailSource.senderEmail,
              subject: emailSource.subject,
              receivedAt: emailSource.receivedAt,
            ),
            transaction,
          );
        }

        for (final controller in _taskControllers) {
          final title = controller.text.trim();
          if (title.isEmpty) {
            continue;
          }
          final task = Task.forInsert(
            jobId: job.id,
            name: title,
            description: '',
            status: TaskStatus.awaitingApproval,
          );
          await daoTask.insert(task, transaction);
        }
      });

      if (mounted) {
        return job;
      }
    } catch (e) {
      HMBToast.error('Failed to create job: $e');
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
    return null;
  }

  bool _isAddressEmpty() =>
      Strings.isBlank(_addressLine1.text) &&
      Strings.isBlank(_addressLine2.text) &&
      Strings.isBlank(_suburb.text) &&
      Strings.isBlank(_postcode.text) &&
      Strings.isBlank(_state.text);
}

class _CustomerMatch {
  final Customer customer;
  final Contact? contact;

  const _CustomerMatch({required this.customer, this.contact});
}

class _ExtractAndMatchStep extends WizardStep {
  final _JobCreatorState state;

  _ExtractAndMatchStep(this.state) : super(title: 'Extract');

  @override
  Widget build(BuildContext context) => Material(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: HMBColumn(
        children: [
          CustomerPastePanel(
            initialMessage: state._pasteMessage,
            onChanged: (value) => state._pasteMessage = value,
            helperText:
                'Paste a customer message to extract the job details using AI, '
                'or skip extraction and enter the job details manually',
            skipLabel: 'Skip',
            extractAvailable: state._aiConfigured,
            onExtractUnavailable: state._showAiRequiredMessage,
            onSkip: () async {
              await wizardState?.jumpToStep(
                state._customerStep,
                userOriginated: false,
              );
            },
            onExtract: (text) async {
              final ok = await state._onExtract(text);
              if (ok) {
                await wizardState?.jumpToStep(
                  state._customerStep,
                  userOriginated: false,
                );
              }
            },
            isExtracting: state._extracting,
          ),
        ],
      ),
    ),
  );
}

class _CustomerStep extends WizardStep {
  final _JobCreatorState state;

  _CustomerStep(this.state) : super(title: 'Customer');

  @override
  Widget build(BuildContext context) => Material(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: HMBColumn(
        children: [
          state._buildCustomerSearchPicker(),
          const HMBSpacer(height: true),
          state._buildExistingCustomerPicker(),
          const HMBSpacer(height: true),
          HMBTextField(
            controller: state._customerName,
            labelText: 'Customer Name',
            textCapitalization: TextCapitalization.words,
            enabled: state._selectedCustomer == null,
            required: state._selectedCustomer == null,
          ),
        ],
      ),
    ),
  );
}

class _ContactStep extends WizardStep {
  final _JobCreatorState state;

  _ContactStep(this.state) : super(title: 'Contact');

  @override
  Widget build(BuildContext context) => Material(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: HMBColumn(
        children: [
          if (state._selectedCustomer != null) ...[
            if (state._existingContacts.length > 8)
              HMBTextField(
                controller: state._existingContactFilter,
                labelText: 'Filter Existing Contacts',
                onChanged: (_) => setState(() {}),
              ),
            Text(
              state._existingContacts.length > 8
                  ? 'Existing contacts '
                        '(${state._filteredExistingContacts().length}/'
                        '${state._existingContacts.length})'
                  : 'Existing contacts',
            ),
            RadioGroup<Contact?>(
              groupValue: state._selectedExistingContact,
              onChanged: (value) => setState(() {
                state._selectedExistingContact = value;
                if (value != null) {
                  state._firstName.text = value.firstName;
                  state._surname.text = value.surname;
                  state._mobileNo.text = value.mobileNumber;
                  state._email.text = value.emailAddress;
                  state._primaryRemoved = false;
                  state._selectedPrimaryContact = value;
                  state._draftPrimaryContact = null;
                } else {
                  state._selectedPrimaryContact = state
                      ._draftPrimaryContactForCurrentFields();
                }
              }),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state._existingContacts.isEmpty)
                    const Text('No existing contacts found')
                  else
                    SizedBox(
                      height: 220,
                      child: ListView(
                        children: state
                            ._filteredExistingContacts()
                            .map(
                              (contact) => RadioListTile<Contact?>(
                                title: Text(
                                  '${contact.firstName} ${contact.surname}'
                                      .trim(),
                                ),
                                subtitle: Text(
                                  contact.emailAddress.isEmpty
                                      ? (contact.mobileNumber.isEmpty
                                            ? 'No details'
                                            : contact.mobileNumber)
                                      : contact.emailAddress,
                                ),
                                value: contact,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const RadioListTile<Contact?>(
                    title: Text('Create new contact'),
                    value: null,
                  ),
                ],
              ),
            ),
            const HMBSpacer(height: true),
          ],
          HMBTextField(
            controller: state._firstName,
            labelText: 'First Name',
            textCapitalization: TextCapitalization.words,
            enabled: state._selectedExistingContact == null,
          ),
          HMBTextField(
            controller: state._surname,
            labelText: 'Surname',
            textCapitalization: TextCapitalization.words,
            enabled: state._selectedExistingContact == null,
          ),
          IgnorePointer(
            ignoring: state._selectedExistingContact != null,
            child: HMBPhoneField(
              controller: state._mobileNo,
              labelText: 'Mobile No.',
              sourceContext: SourceContext(),
            ),
          ),
          IgnorePointer(
            ignoring: state._selectedExistingContact != null,
            child: HMBEmailField(
              controller: state._email,
              labelText: 'Email Address',
            ),
          ),
        ],
      ),
    ),
  );
}

class _AddressStep extends WizardStep {
  final _JobCreatorState state;

  _AddressStep(this.state) : super(title: 'Address');

  @override
  Widget build(BuildContext context) => Material(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: HMBColumn(
        children: [
          const Text('Customer address'),
          if (state._selectedCustomer != null) ...[
            if (state._existingSites.length > 8)
              HMBTextField(
                controller: state._existingSiteFilter,
                labelText: 'Filter Existing Sites',
                onChanged: (_) => setState(() {}),
              ),
            Text(
              state._existingSites.length > 8
                  ? 'Existing sites '
                        '(${state._filteredExistingSites().length}/'
                        '${state._existingSites.length})'
                  : 'Existing sites',
            ),
            RadioGroup<Site?>(
              groupValue: state._selectedExistingSite,
              onChanged: (value) => setState(() {
                state._selectedExistingSite = value;
                if (value != null) {
                  state._addressLine1.text = value.addressLine1;
                  state._addressLine2.text = value.addressLine2;
                  state._suburb.text = value.suburb;
                  state._state.text = value.state;
                  state._postcode.text = value.postcode;
                }
              }),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state._existingSites.isEmpty)
                    const Text('No existing sites found')
                  else
                    SizedBox(
                      height: 220,
                      child: ListView(
                        children: state
                            ._filteredExistingSites()
                            .map(
                              (site) => RadioListTile<Site?>(
                                title: Text(site.addressLine1),
                                subtitle: Text(
                                  Strings.join(
                                    [site.suburb, site.state, site.postcode],
                                    separator: ' ',
                                    excludeEmpty: true,
                                  ),
                                ),
                                value: site,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const RadioListTile<Site?>(
                    title: Text('Create new site'),
                    value: null,
                  ),
                ],
              ),
            ),
            const HMBSpacer(height: true),
          ],
          HMBTextField(
            controller: state._addressLine1,
            labelText: 'Address Line 1',
            textCapitalization: TextCapitalization.words,
            enabled: state._selectedExistingSite == null,
          ),
          HMBTextField(
            controller: state._addressLine2,
            labelText: 'Address Line 2',
            textCapitalization: TextCapitalization.words,
            enabled: state._selectedExistingSite == null,
          ),
          HMBTextField(
            controller: state._suburb,
            labelText: 'Suburb',
            textCapitalization: TextCapitalization.words,
            enabled: state._selectedExistingSite == null,
          ),
          HMBTextField(
            controller: state._state,
            labelText: 'State',
            textCapitalization: TextCapitalization.words,
            enabled: state._selectedExistingSite == null,
          ),
          HMBTextField(
            controller: state._postcode,
            labelText: 'Postcode',
            textCapitalization: TextCapitalization.characters,
            enabled: state._selectedExistingSite == null,
          ),
          HMBToggle(
            label: 'Site same as customer',
            hint: 'Use the customer address as the job site',
            initialValue: state._sameSiteAddress,
            onToggled: (value) =>
                setState(() => state._sameSiteAddress = value),
          ),
          if (!state._sameSiteAddress) ...[
            const Text('Job site address'),
            for (var index = 0; index < 5; index++)
              HMBTextField(
                controller: state._siteAddress[index],
                labelText: const [
                  'Site address line 1',
                  'Site address line 2',
                  'Site suburb',
                  'Site state',
                  'Site postcode',
                ][index],
                required: index == 0,
                textCapitalization: TextCapitalization.words,
              ),
          ],
        ],
      ),
    ),
  );
}

class _PartiesStep extends WizardStep {
  final _JobCreatorState state;
  _PartiesStep(this.state) : super(title: 'Parties');
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(12), child: state._buildParties());
}

class _BillingStep extends WizardStep {
  final _JobCreatorState state;
  _BillingStep(this.state) : super(title: 'Billing');
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(12), child: state._buildBilling());
}

class _JobStep extends WizardStep {
  final _JobCreatorState state;

  _JobStep(this.state) : super(title: 'Job');

  @override
  Widget build(BuildContext context) => Material(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: HMBColumn(
        children: [
          HMBTextField(
            controller: state._jobSummary,
            labelText: 'Job Summary',
            required: true,
            fieldKey: TestKeys.jobCreatorSummaryField,
          ),
          TextFormField(
            key: TestKeys.jobCreatorDescriptionField,
            controller: state._jobDescription,
            decoration: const InputDecoration(labelText: 'Job Description'),
            maxLines: 5,
          ),
          const HMBSpacer(height: true),
          state._buildTaskList(),
        ],
      ),
    ),
  );
}
