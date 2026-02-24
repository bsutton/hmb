import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../../api/chat_gpt/customer_extract_api_client.dart';
import '../../../api/chat_gpt/job_assist_api_client.dart';
import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/money_ex.dart';
import '../../../util/dart/parse/parse_customer.dart';
import '../../crud/customer/customer_paste_panel.dart';
import '../../dialog/source_context.dart';
import '../../widgets/fields/hmb_email_field.dart';
import '../../widgets/fields/hmb_phone_field.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/select.g.dart';
import '../../widgets/widgets.g.dart';
import 'post_job_todo_prompt.dart';

class JobCreator extends StatefulWidget {
  const JobCreator({super.key});

  static Future<Job?> show(BuildContext context) async {
    if (!context.mounted) {
      return null;
    }
    return showDialog<Job>(
      context: context,
      builder: (context) => const JobCreator(),
    );
  }

  @override
  State<JobCreator> createState() => _JobCreatorState();
}

class _JobCreatorState extends State<JobCreator> {
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
  final _jobSummary = TextEditingController();
  final _jobDescription = TextEditingController();
  final _taskControllers = <TextEditingController>[];
  var _pasteMessage = '';
  BillingType _selectedBillingType = BillingType.timeAndMaterial;

  var _creating = false;
  var _extracting = false;
  Customer? _selectedCustomer;
  List<_CustomerMatch> _matches = [];
  List<Contact> _existingContacts = [];
  List<Site> _existingSites = [];
  Contact? _selectedExistingContact;
  Site? _selectedExistingSite;
  late final List<WizardStep> _steps;
  late final _CustomerStep _customerStep;

  @override
  void initState() {
    super.initState();
    _customerStep = _CustomerStep(this);
    _steps = [
      _ExtractAndMatchStep(this),
      _customerStep,
      _ContactStep(this),
      _AddressStep(this),
      _JobStep(this),
    ];
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
    _jobSummary.dispose();
    _jobDescription.dispose();
    for (final controller in _taskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface =
        theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface;

    return AlertDialog(
      insetPadding: const EdgeInsets.all(10),
      contentPadding: const EdgeInsets.all(8),
      title: const Text('Create Job Wizard'),
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
                  decoration: InputDecoration(
                    labelText: 'Task ${index + 1}',
                    border: const OutlineInputBorder(),
                  ),
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

  Widget _buildExistingCustomerPicker() => RadioGroup<Customer?>(
    groupValue: _selectedCustomer,
    onChanged: (value) {
      setState(() {
        _selectedCustomer = value;
        if (value != null) {
          _customerName.text = value.name;
          unawaited(_loadExistingCustomerDetails(value));
        } else {
          _existingContacts = [];
          _existingSites = [];
          _selectedExistingContact = null;
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
        _selectedCustomer = customer;
        if (customer != null) {
          _customerName.text = customer.name;
          unawaited(_loadExistingCustomerDetails(customer));
        } else {
          _existingContacts = [];
          _existingSites = [];
          _selectedExistingContact = null;
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
      _selectedExistingSite = sites.isEmpty ? null : sites.first;
    });
  }

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

  String _displayName(Contact contact) =>
      '${contact.firstName} ${contact.surname}'.trim();

  Future<bool> _onExtract(String text) async {
    if (_extracting) {
      return false;
    }
    if (Strings.isBlank(text)) {
      return true;
    }

    var extracted = false;
    setState(() => _extracting = true);
    try {
      await BlockingUI().runAndWait(() async {
        ParsedCustomer parsedCustomer;
        final system = await DaoSystem().get();
        final apiKey = system.openaiApiKey?.trim() ?? '';
        if (apiKey.isNotEmpty) {
          final extracted = await CustomerExtractApiClient().extract(text);
          if (extracted == null) {
            HMBToast.error('AI extraction failed. Check ChatGPT settings.');
            return;
          }
          parsedCustomer = extracted;
        } else {
          parsedCustomer = await ParsedCustomer.parse(text);
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

        if (apiKey.isNotEmpty) {
          await _generateSummaryAndTasks(text);
        } else if (Strings.isBlank(_jobDescription.text)) {
          _jobDescription.text = text;
        }

        await _loadMatches(parsedCustomer);
        extracted = true;
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
    return extracted;
  }

  Future<void> _generateSummaryAndTasks(String text) async {
    if (Strings.isBlank(text)) {
      return;
    }

    final client = JobAssistApiClient();
    final result = await client.analyzeDescription(text);
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
        final job = await _createEntities();
        if (job != null && mounted) {
          await promptForPostJobTodo(context: context, job: job);
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

      late Customer customer;
      Contact? contact;
      Site? site;
      late Job job;

      await daoCustomer.withTransaction((transaction) async {
        if (_selectedCustomer != null) {
          customer = _selectedCustomer!;
          if (_selectedExistingContact != null) {
            contact = _selectedExistingContact;
          } else {
            contact = Contact.forInsert(
              firstName: _firstName.text,
              surname: _surname.text,
              mobileNumber: _mobileNo.text,
              landLine: '',
              officeNumber: '',
              emailAddress: _email.text,
            );
            await daoContact.insert(contact!, transaction);
            await DaoContactCustomer().insertJoin(
              contact!,
              customer,
              transaction,
            );
          }
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

          contact = Contact.forInsert(
            firstName: _firstName.text,
            surname: _surname.text,
            mobileNumber: _mobileNo.text,
            landLine: '',
            officeNumber: '',
            emailAddress: _email.text,
          );
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
        }

        if (customer.billingContactId == null && contact != null) {
          final customer2 = customer.copyWith(billingContactId: contact!.id);
          await daoCustomer.update(customer2, transaction);
        }

        final summary = Strings.isBlank(_jobSummary.text)
            ? 'New Job'
            : _jobSummary.text;
        job = Job.forInsert(
          customerId: customer.id,
          summary: summary,
          description: _jobDescription.text,
          siteId: site?.id,
          contactId: contact?.id,
          status: JobStatus.prospecting,
          billingType: _selectedBillingType,
          hourlyRate:
              system.defaultHourlyRate ?? Money.fromInt(0, isoCode: 'AUD'),
          bookingFee:
              system.defaultBookingFee ?? Money.fromInt(0, isoCode: 'AUD'),
          billingContactId: contact?.id,
        );
        await daoJob.insert(job, transaction);

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
            RadioGroup<Contact?>(
              groupValue: state._selectedExistingContact,
              onChanged: (value) => setState(() {
                state._selectedExistingContact = value;
                if (value != null) {
                  state._firstName.text = value.firstName;
                  state._surname.text = value.surname;
                  state._mobileNo.text = value.mobileNumber;
                  state._email.text = value.emailAddress;
                }
              }),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state._existingContacts.isEmpty
                        ? 'No existing contacts found'
                        : 'Existing contacts',
                  ),
                  ...state._existingContacts.map(
                    (contact) => RadioListTile<Contact?>(
                      title: Text(
                        '${contact.firstName} ${contact.surname}'.trim(),
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
          if (state._selectedCustomer != null) ...[
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
                  Text(
                    state._existingSites.isEmpty
                        ? 'No existing sites found'
                        : 'Existing sites',
                  ),
                  ...state._existingSites.map(
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
        ],
      ),
    ),
  );
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
          HMBDroplist<BillingType>(
            title: 'Billing Type',
            selectedItem: () => Future.value(state._selectedBillingType),
            items: (_) => Future.value(BillingType.values),
            format: (type) => type.display,
            onChanged: (type) {
              if (type != null) {
                state._selectedBillingType = type;
              }
            },
          ),
          HMBTextField(
            controller: state._jobSummary,
            labelText: 'Job Summary',
            required: true,
          ),
          TextFormField(
            controller: state._jobDescription,
            decoration: const InputDecoration(
              labelText: 'Job Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
          const HMBSpacer(height: true),
          state._buildTaskList(),
        ],
      ),
    ),
  );
}
