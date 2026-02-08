import 'dart:async';

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
import '../../widgets/widgets.g.dart';

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
  final _formKey = GlobalKey<FormState>();

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

  var _creating = false;
  var _extracting = false;
  var _useExistingContact = true;
  Customer? _selectedCustomer;
  List<_CustomerMatch> _matches = [];

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
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(6),
    title: const Text('Create Job'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: double.maxFinite,
        child: HMBColumn(
          children: [
            CustomerPastePanel(
              onExtract: _onExtract,
              isExtracting: _extracting,
            ),
            if (_matches.isNotEmpty) ...[
              const HMBSpacer(height: true),
              _buildExistingCustomerPicker(),
            ],
            const HMBSpacer(height: true),
            Form(
              key: _formKey,
              child: HMBColumn(
                children: [
                  HMBTextField(
                    controller: _customerName,
                    labelText: 'Customer Name',
                    textCapitalization: TextCapitalization.words,
                    enabled: _selectedCustomer == null,
                    required: _selectedCustomer == null,
                  ),
                  HMBTextField(
                    controller: _firstName,
                    labelText: 'First Name',
                    textCapitalization: TextCapitalization.words,
                  ),
                  HMBTextField(
                    controller: _surname,
                    labelText: 'Surname',
                    textCapitalization: TextCapitalization.words,
                  ),
                  HMBPhoneField(
                    controller: _mobileNo,
                    labelText: 'Mobile No.',
                    sourceContext: SourceContext(),
                  ),
                  HMBEmailField(controller: _email, labelText: 'Email Address'),
                  HMBTextField(
                    controller: _addressLine1,
                    labelText: 'Address Line 1',
                    textCapitalization: TextCapitalization.words,
                  ),
                  HMBTextField(
                    controller: _addressLine2,
                    labelText: 'Address Line 2',
                    textCapitalization: TextCapitalization.words,
                  ),
                  HMBTextField(
                    controller: _suburb,
                    labelText: 'Suburb',
                    textCapitalization: TextCapitalization.words,
                  ),
                  HMBTextField(
                    controller: _state,
                    labelText: 'State',
                    textCapitalization: TextCapitalization.words,
                  ),
                  HMBTextField(
                    controller: _postcode,
                    labelText: 'Postcode',
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const HMBSpacer(height: true),
                  Row(
                    children: [
                      Expanded(
                        child: HMBTextField(
                          controller: _jobSummary,
                          labelText: 'Job Summary',
                          required: true,
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _jobDescription,
                    decoration: const InputDecoration(
                      labelText: 'Job Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                  const HMBSpacer(height: true),
                  _buildTaskList(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      HMBButtonPrimary(
        label: 'Create Job',
        hint: 'Create a job from this booking request',
        onPressed: _creating ? null : _createEntities,
      ),
    ],
  );

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
        _useExistingContact = value != null;
        if (value != null) {
          _customerName.text = value.name;
        }
      });
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Existing customer matches'),
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
        if (_selectedCustomer != null)
          SwitchListTile(
            title: const Text('Use existing primary contact'),
            value: _useExistingContact,
            onChanged: (value) => setState(() => _useExistingContact = value),
          ),
      ],
    ),
  );

  Future<void> _onExtract(String text) async {
    if (_extracting) {
      return;
    }
    if (Strings.isBlank(text)) {
      HMBToast.info('Paste a message to extract job details.');
      return;
    }

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
    setState(() {
      _matches = matches;
      if (_selectedCustomer != null &&
          !_matches.any((m) => m.customer.id == _selectedCustomer!.id)) {
        _selectedCustomer = null;
        _useExistingContact = true;
      }
    });
  }

  Future<void> _createEntities() async {
    if (!_formKey.currentState!.validate()) {
      return;
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
          if (_useExistingContact) {
            contact = await daoContact.getPrimaryForCustomer(
              customer.id,
              transaction,
            );
            if (contact == null) {
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

        if (!_isAddressEmpty()) {
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
        Navigator.of(context).pop(job);
      }
    } catch (e) {
      HMBToast.error('Failed to create job: $e');
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
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
