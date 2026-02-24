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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../api/chat_gpt/job_assist_api_client.dart';
import '../../api/ihserver/ihserver_api_client.dart';
import '../../dao/dao_booking_request.dart';
import '../../dao/dao_contact.dart';
import '../../dao/dao_contact_customer.dart';
import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_site.dart';
import '../../dao/dao_site_customer.dart';
import '../../dao/dao_system.dart';
import '../../dao/dao_task.dart';
import '../../entity/booking_request.dart';
import '../../entity/contact.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../entity/job_status.dart';
import '../../entity/site.dart';
import '../../entity/task.dart';
import '../../entity/task_status.dart';
import '../../util/dart/money_ex.dart';
import '../crud/job/post_job_todo_prompt.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/widgets.g.dart';

class BookingRequestReviewDialog extends StatefulWidget {
  final BookingRequest request;

  const BookingRequestReviewDialog(this.request, {super.key});

  static Future<void> show(BuildContext context, BookingRequest request) async {
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => BookingRequestReviewDialog(request),
    );
  }

  @override
  State<BookingRequestReviewDialog> createState() =>
      _BookingRequestReviewDialogState();
}

class _BookingRequestReviewDialogState
    extends State<BookingRequestReviewDialog> {
  final _formKey = GlobalKey<FormState>();

  final _businessName = TextEditingController();
  final _firstName = TextEditingController();
  final _surname = TextEditingController();
  final _mobileNo = TextEditingController();
  final _email = TextEditingController();
  final _addressLine1 = TextEditingController();
  final _addressLine2 = TextEditingController();
  final _suburb = TextEditingController();
  final _state = TextEditingController();
  final _postcode = TextEditingController();
  final _jobSummary = TextEditingController();
  final _jobDescription = TextEditingController();

  final _taskControllers = <TextEditingController>[];

  var _loading = false;
  var _useExistingContact = true;
  Customer? _selectedCustomer;
  List<_CustomerMatch> _matches = [];

  BookingRequestPayload get _payload => widget.request.parsedPayload;

  @override
  void initState() {
    super.initState();
    _seedFields();
    unawaited(_loadMatches());
    unawaited(_generateSummaryAndTasks(initialOnly: true));
  }

  void _seedFields() {
    final name = _payload.name;
    _businessName.text = _payload.businessName;
    _firstName.text = _payload.firstName;
    _surname.text = _payload.surname;
    _jobDescription.text = _payload.description;
    _email.text = _payload.email;
    _mobileNo.text = _payload.phone;

    if (_businessName.text.isEmpty &&
        _firstName.text.isEmpty &&
        _surname.text.isEmpty) {
      if (name.contains(' ')) {
        final parts = name.split(' ');
        _firstName.text = parts.first;
        _surname.text = parts.skip(1).join(' ');
      } else {
        _firstName.text = name;
        _surname.text = '';
      }
    }

    _addressLine1.text = _payload.street;
    _suburb.text = _payload.suburb;
  }

  Future<void> _loadMatches() async {
    final matches = <_CustomerMatch>[];
    final seen = <int>{};
    final daoContact = DaoContact();
    final daoCustomer = DaoCustomer();

    if (Strings.isNotBlank(_payload.email)) {
      final contacts = await daoContact.getByEmail(_payload.email);
      for (final contact in contacts) {
        final customer = await daoCustomer.getByContact(contact.id);
        if (customer != null && seen.add(customer.id)) {
          matches.add(_CustomerMatch(customer: customer, contact: contact));
        }
      }
    }

    if (Strings.isNotBlank(_payload.phone)) {
      final contacts = await daoContact.getByMobile(_payload.phone);
      for (final contact in contacts) {
        final customer = await daoCustomer.getByContact(contact.id);
        if (customer != null && seen.add(customer.id)) {
          matches.add(_CustomerMatch(customer: customer, contact: contact));
        }
      }
    }

    if (Strings.isNotBlank(_payload.name)) {
      final customers = await daoCustomer.getByName(_payload.name);
      for (final customer in customers) {
        if (seen.add(customer.id)) {
          matches.add(_CustomerMatch(customer: customer));
        }
      }
    }

    if (mounted) {
      setState(() => _matches = matches);
    }
  }

  Future<void> _generateSummaryAndTasks({required bool initialOnly}) async {
    if (Strings.isBlank(_jobDescription.text)) {
      return;
    }
    if (initialOnly && Strings.isNotBlank(_jobSummary.text)) {
      return;
    }

    final system = await DaoSystem().get();
    final apiKey = system.openaiApiKey?.trim() ?? '';
    if (apiKey.isEmpty) {
      if (!initialOnly && mounted) {
        await _showChatGptConfigDialog(context);
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final client = JobAssistApiClient();
      final result = await client.analyzeDescription(_jobDescription.text);
      if (result == null) {
        return;
      }
      if (Strings.isBlank(_jobSummary.text)) {
        _jobSummary.text = result.summary;
      }
      if (Strings.isBlank(_jobDescription.text) &&
          Strings.isNotBlank(result.description)) {
        _jobDescription.text = result.description;
      }
      if (_taskControllers.isEmpty) {
        for (final task in result.tasks) {
          _taskControllers.add(TextEditingController(text: task));
        }
      }
    } catch (e) {
      HMBToast.error('AI extraction failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _businessName.dispose();
    _firstName.dispose();
    _surname.dispose();
    _mobileNo.dispose();
    _email.dispose();
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
    title: const Text('Review Booking Request'),
    content: SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: HMBColumn(
          children: [
            if (_matches.isNotEmpty) _buildExistingCustomerPicker(),
            const HMBSpacer(height: true),
            Form(
              key: _formKey,
              child: HMBColumn(
                children: [
                  HMBTextField(
                    controller: _businessName,
                    labelText: 'Business Name (optional)',
                    textCapitalization: TextCapitalization.words,
                    enabled: _selectedCustomer == null,
                  ),
                  HMBTextField(
                    controller: _firstName,
                    labelText: 'First Name',
                    textCapitalization: TextCapitalization.words,
                    enabled: _selectedCustomer == null || !_useExistingContact,
                    validator: (value) {
                      if (_selectedCustomer != null) {
                        return null;
                      }
                      if (Strings.isNotBlank(_businessName.text)) {
                        return null;
                      }
                      if (Strings.isBlank(value)) {
                        return 'Please enter a First Name';
                      }
                      return null;
                    },
                  ),
                  HMBTextField(
                    controller: _surname,
                    labelText: 'Surname',
                    textCapitalization: TextCapitalization.words,
                    enabled: _selectedCustomer == null || !_useExistingContact,
                  ),
                  HMBTextField(
                    controller: _mobileNo,
                    labelText: 'Mobile No.',
                    keyboardType: TextInputType.phone,
                    enabled: _selectedCustomer == null || !_useExistingContact,
                  ),
                  HMBTextField(
                    controller: _email,
                    labelText: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    enabled: _selectedCustomer == null || !_useExistingContact,
                  ),
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
                      IconButton(
                        onPressed: _loading
                            ? null
                            : () =>
                                  _generateSummaryAndTasks(initialOnly: false),
                        icon: const Icon(Icons.auto_fix_high),
                        tooltip: 'Generate summary & tasks',
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
      if (widget.request.status != BookingRequestStatus.imported)
        TextButton(
          onPressed: _loading ? null : _deleteRequest,
          child: const Text('Delete'),
        ),
      if (widget.request.status == BookingRequestStatus.rejected)
        TextButton(
          onPressed: _loading ? null : _unrejectRequest,
          child: const Text('Unreject'),
        )
      else if (widget.request.status != BookingRequestStatus.imported)
        TextButton(
          onPressed: _loading ? null : _rejectRequest,
          child: const Text('Reject'),
        ),
      HMBButtonPrimary(
        label: 'Create Job',
        hint: 'Create a job from this booking request',
        onPressed: _loading ? null : _createEntities,
      ),
    ],
  );

  Widget _buildExistingCustomerPicker() => RadioGroup<Customer?>(
    groupValue: _selectedCustomer,
    onChanged: (value) {
      setState(() {
        _selectedCustomer = value;
        _useExistingContact = value != null;
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

  Future<void> _createEntities() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);
    try {
      final daoCustomer = DaoCustomer();
      final daoContact = DaoContact();
      final daoSite = DaoSite();
      final daoJob = DaoJob();
      final daoTask = DaoTask();
      final daoSystem = DaoSystem();
      final system = await daoSystem.get();

      Customer customer;
      Contact? contact;
      Site? site;
      Job? createdJob;

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
            name: _resolveCustomerName(),
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
          final existingSites = await daoSite.getByCustomer(
            customer.id,
            transaction,
          );
          site = existingSites.firstWhere(
            _isSameAddress,
            orElse: () => Site.forInsert(
              addressLine1: _addressLine1.text,
              addressLine2: _addressLine2.text,
              suburb: _suburb.text,
              postcode: _postcode.text,
              state: _state.text,
              accessDetails: null,
            ),
          );

          if (site!.id == -1) {
            await daoSite.insert(site!, transaction);
            await DaoSiteCustomer().insertJoin(site!, customer, transaction);
          }
        }

        if (customer.billingContactId == null && contact != null) {
          await daoCustomer.update(
            customer.copyWith(billingContactId: contact!.id),
            transaction,
          );
        }

        final summary = Strings.isBlank(_jobSummary.text)
            ? _fallbackSummary()
            : _jobSummary.text;
        final job = Job.forInsert(
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
        createdJob = job;

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

      await DaoBookingRequest().markImported(widget.request);
      if (mounted && createdJob != null) {
        await promptForPostJobTodo(context: context, job: createdJob!);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      HMBToast.error('Failed to create job: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteRequest() async {
    final customerName = _resolvedCustomerName();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete enquiry?'),
        content: Text(
          'Delete enquiry for "$customerName"?\n'
          'This will remove it from the pending list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _loading = true);
    try {
      await DaoBookingRequest().delete(widget.request.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      HMBToast.error('Failed to delete enquiry: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _rejectRequest() async {
    if (_payload.email.isEmpty) {
      HMBToast.error('No email address on this enquiry to send a rejection.');
      return;
    }

    final reason = await _askRejectReason();
    if (reason == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      await IhServerApiClient().rejectBookingRequest(
        widget.request.remoteId,
        reason,
      );
      await DaoBookingRequest().update(
        widget.request.copyWith(status: BookingRequestStatus.rejected),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      HMBToast.error('Failed to reject enquiry: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String?> _askRejectReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject enquiry'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                HMBToast.error('Please enter a rejection reason.');
                return;
              }
              Navigator.of(context).pop(text);
            },
            child: const Text('Send rejection'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _unrejectRequest() async {
    setState(() => _loading = true);
    try {
      await DaoBookingRequest().update(
        widget.request.copyWith(status: BookingRequestStatus.pending),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      HMBToast.error('Failed to unreject enquiry: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showChatGptConfigDialog(BuildContext context) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ChatGPT integration not configured'),
          content: const Text(
            'Add your OpenAI API key to enable job summaries and task '
            'suggestions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                GoRouter.of(context).go('/home/settings/integrations/chatgpt');
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      );

  bool _isAddressEmpty() =>
      Strings.isBlank(_addressLine1.text) &&
      Strings.isBlank(_addressLine2.text) &&
      Strings.isBlank(_suburb.text) &&
      Strings.isBlank(_postcode.text) &&
      Strings.isBlank(_state.text);

  bool _isSameAddress(Site site) =>
      site.addressLine1.trim().toLowerCase() ==
          _addressLine1.text.trim().toLowerCase() &&
      site.suburb.trim().toLowerCase() == _suburb.text.trim().toLowerCase();

  String _fallbackSummary() {
    final resolvedName = _resolveCustomerName();
    final name = resolvedName.isNotEmpty ? resolvedName : 'Enquiry';
    final suburb = _payload.suburb.isNotEmpty ? _payload.suburb : '';
    return suburb.isEmpty ? 'Enquiry - $name' : 'Enquiry - $name - $suburb';
  }

  String _resolveCustomerName() {
    final businessName = _businessName.text.trim();
    if (businessName.isNotEmpty) {
      return businessName;
    }
    final firstName = _firstName.text.trim();
    final surname = _surname.text.trim();
    if (firstName.isEmpty) {
      return surname;
    }
    return Strings.isBlank(surname) ? firstName : '$firstName $surname';
  }

  String _resolvedCustomerName() {
    final businessName = _payload.businessName.trim();
    if (businessName.isNotEmpty) {
      return businessName;
    }
    final firstName = _payload.firstName.trim();
    final surname = _payload.surname.trim();
    if (firstName.isNotEmpty || surname.isNotEmpty) {
      return Strings.isBlank(surname) ? firstName : '$firstName $surname';
    }
    if (_payload.name.isNotEmpty) {
      return _payload.name;
    }
    return 'Enquiry';
  }
}

class _CustomerMatch {
  final Customer customer;
  final Contact? contact;

  _CustomerMatch({required this.customer, this.contact});
}
