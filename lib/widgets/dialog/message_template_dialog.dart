import 'package:flutter/material.dart';
import 'package:money2/money2.dart';
import 'package:strings/strings.dart';

import '../../../entity/message_template.dart';
import '../../dao/dao_contact.dart';
import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_message_template.dart';
import '../../dao/dao_site.dart';
import '../../dao/dao_system.dart';
import '../../entity/contact.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../entity/site.dart';
import '../../entity/supplier.dart';
import '../async_state.dart';
import '../hmb_date_time_picker.dart';
import '../select/hmb_droplist.dart';

class PlaceHolderField {
  PlaceHolderField({
    required this.placeholder,
    required this.widget,
    required this.getValue,
    this.controller,
  });

  final String placeholder;
  final TextEditingController? controller;
  final Widget widget;
  final Future<String> Function() getValue;
}

class MessageTemplateDialog extends StatefulWidget {
  const MessageTemplateDialog({
    super.key,
    this.job,
    this.customer,
    this.supplier,
    this.contact,
  });

  final Job? job;
  final Customer? customer;
  final Contact? contact;
  final Supplier? supplier;

  @override
  _MessageTemplateDialogState createState() => _MessageTemplateDialogState();
}

Future<SelectedMessageTemplate?> showMessageTemplateDialog(
  BuildContext context, {
  Customer? customer,
  Job? job,
  Contact? contact,
  Supplier? supplier,
}) async =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MessageTemplateDialog(
          customer: customer,
          job: job,
          supplier: supplier,
          contact: contact,
        ),
      ),
    );

class _MessageTemplateDialogState
    extends AsyncState<MessageTemplateDialog, void>
    with SingleTickerProviderStateMixin {
  List<MessageTemplate> _templates = [];
  MessageTemplate? _selectedTemplate;
  String _signature = '';

  final Map<String, PlaceHolderField> placeholderFields = {};
  Customer? _selectedCustomer;
  Job? _selectedJob;
  Site? _selectedSite;
  Contact? _selectedContact;

  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();

  @override
  Future<void> asyncInitState() async {
    _tabController = TabController(length: 2, vsync: this);
    await _loadTemplates();
    await _fetchSignature();
    _selectedCustomer = widget.customer;
    _selectedContact = widget.contact;
    if (widget.job != null) {
      await _loadJobDetails(widget.job!);
    }
    _selectedSite ??=
        (await DaoSite().getByCustomer(_selectedCustomer?.id)).firstOrNull;

    _selectedContact ??=
        (await DaoContact().getByCustomer(_selectedCustomer?.id)).firstOrNull;
  }

  Future<void> _fetchSignature() async {
    final system = await DaoSystem().get();
    _signature =
        '${system?.firstname ?? ''} ${system?.surname ?? ''}\n${system?.businessName ?? ''}';
  }

  Future<void> _loadTemplates() async {
    final templates = await DaoMessageTemplate().getByFilter(null);
    setState(() {
      _templates = _filterTemplates(templates);
    });
  }

  Future<void> _loadJobDetails(Job job) async {
    final customer = await DaoCustomer().getById(job.customerId);
    final site = await DaoSite().getById(job.siteId);
    _selectedCustomer = customer;
    _selectedSite = site;
    _selectedContact = job.contactId != null
        ? await DaoContact().getById(job.contactId)
        : null;
    setState(() {});
  }

  List<MessageTemplate> _filterTemplates(List<MessageTemplate> templates) {
    // Filter based on the screen type
    if (widget.job != null) {
      return templates;
    } else if (widget.customer != null) {
      return templates
          .where((t) => t.message.contains('{{customer_}}'))
          .toList();
    } else if (widget.supplier != null) {
      return templates
          .where((t) => t.message.contains('{{supplier_}}'))
          .toList();
    } else if (widget.contact != null) {
      return templates
          .where((t) => t.message.contains('{{contact_}}'))
          .toList();
    }
    return templates;
  }

  void _initializePlaceholders() {
    if (_selectedTemplate != null) {
      final regExp = RegExp(r'\{\{(\w+)\}\}');
      final matches = regExp.allMatches(_selectedTemplate!.message);

      // Get the list of placeholders in the new template
      final newPlaceholders = matches.map((m) => m.group(1)!).toSet();

      // Remove placeholders that are no longer in the new template
      placeholderFields.keys
          .where((key) => !newPlaceholders.contains(key))
          .toList()
          .forEach(placeholderFields.remove);

      // Add new placeholders or keep existing ones
      for (final placeholder in newPlaceholders) {
        if (placeholder != 'signature' &&
            !placeholderFields.containsKey(placeholder)) {
          placeholderFields[placeholder] = _buildPlaceHolderField(placeholder);
        }
      }
    }
  }

  /// find the matching placeholder
  PlaceHolderField _buildPlaceHolderField(String placeholder) {
    if (placeholder.contains('time')) {
      return _buildTimePicker(placeholder);
    } else if (placeholder.contains('date')) {
      return _buildDatePicker(placeholder);
    } else if (placeholder == 'delay_period') {
      return _buildPeriodPicker(placeholder);
    } else if (placeholder == 'customer_name') {
      return _buildCustomerDroplist(placeholder);
    } else if (placeholder == 'site') {
      return _buildSiteDroplist(placeholder);
    } else if (placeholder == 'contact_name') {
      return _buildContactDroplist(placeholder);
    } else if (placeholder.contains('job')) {
      return _buildJobDroplist(placeholder);
    }

    // Default TextFormField for other placeholders
    final controller =
        placeholderFields[placeholder]?.controller ?? TextEditingController();
    final widget = TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: placeholder.toCapitalised()),
    );
    return PlaceHolderField(
        placeholder: placeholder,
        controller: controller,
        widget: widget,
        getValue: () async => controller.text);
  }

  /// Customer placeholder drop list
  PlaceHolderField _buildCustomerDroplist(String placeholder) {
    final controller =
        placeholderFields[placeholder]?.controller ?? TextEditingController();

    // Set controller's text to current selected customer
    if (_selectedCustomer != null) {
      controller.text = _selectedCustomer!.name;
    }

    final widget = HMBDroplist<Customer>(
      title: 'Customer',
      selectedItem: () async => _selectedCustomer,
      items: (filter) async => DaoCustomer().getByFilter(filter),
      format: (customer) => customer.name,
      onChanged: (customer) {
        setState(() {
          _selectedCustomer = customer;
          controller.text = customer?.name ?? '';
          // Reset site and contact when customer changes
          _selectedSite = null;
          _selectedContact = null;
        });
      },
    );
    return PlaceHolderField(
        placeholder: placeholder,
        controller: controller,
        widget: widget,
        getValue: () async => controller.text);
  }

  /// Job placeholder drop list
  PlaceHolderField _buildJobDroplist(String placeholder) {
    final controller =
        placeholderFields[placeholder]?.controller ?? TextEditingController();

    // Set controller's text to current selected job
    if (_selectedJob != null) {
      controller.text = _selectedJob!.description;
    }

    final widget = HMBDroplist<Job>(
      title: 'Job',
      selectedItem: () async => _selectedJob,
      items: (filter) async => DaoJob().getByFilter(filter),
      format: (job) => job.summary,
      onChanged: (job) {
        setState(() {
          _selectedJob = job;
          controller.text = job?.summary ?? '';
          // Reset site and contact when job changes
          _selectedSite = null;
          _selectedContact = null;
        });
      },
    );
    return PlaceHolderField(
        placeholder: placeholder,
        widget: widget,
        getValue: () async =>
            (await _getJobValue(placeholder)) ?? controller.text);
  }

  Future<Money> jobCost(Job job) async =>
      (await DaoJob().getJobStatistics(job)).totalCost;

  /// Site placeholder drop list
  PlaceHolderField _buildSiteDroplist(String placeholder) {
    final controller =
        placeholderFields[placeholder]?.controller ?? TextEditingController();

    // Set controller's text to current selected site
    if (_selectedSite != null) {
      controller.text = _selectedSite!.address;
    }

    final droplist = HMBDroplist<Site>(
      title: 'Site',
      selectedItem: () async => _selectedSite,
      items: (filter) async {
        if (_selectedCustomer != null) {
          // Fetch sites associated with the selected customer
          return DaoSite().getByFilter(_selectedCustomer!.id, filter);
        } else {
          // Fetch all sites
          return DaoSite().getAll();
        }
      },
      format: (site) => site.address,
      onChanged: (site) {
        setState(() {
          _selectedSite = site;
          controller.text = site?.address ?? '';
        });
      },
    );
    return PlaceHolderField(
      placeholder: placeholder,
      controller: controller,
      widget: droplist,
      getValue: () async => controller.text,
    );
  }

  /// Contact placeholder drop list
  PlaceHolderField _buildContactDroplist(String placeholder) {
    final controller =
        placeholderFields[placeholder]?.controller ?? TextEditingController();

    // Set controller's text to current selected contact
    if (_selectedContact != null) {
      controller.text = _selectedContact!.fullname;
    }

    final droplist = HMBDroplist<Contact>(
      title: 'Contact',
      selectedItem: () async => _selectedContact,
      items: (filter) async {
        if (widget.job != null && widget.job!.contactId != null) {
          final contact = await DaoContact().getById(widget.job!.contactId);
          return [contact!];
        } else {
          final customer = await DaoCustomer().getById(widget.job!.customerId);
          return DaoContact().getByFilter(customer!, filter);
        }
      },
      format: (contact) => contact.fullname,
      onChanged: (contact) {
        setState(() {
          _selectedContact = contact;
          controller.text = contact?.fullname ?? '';
        });
      },
    );
    return PlaceHolderField(
      placeholder: placeholder,
      controller: controller,
      widget: droplist,
      getValue: () async => controller.text,
    );
  }

  /// Time placeholder drop list
  PlaceHolderField _buildTimePicker(String placeholder) {
    final controller =
        placeholderFields[placeholder]?.controller ?? TextEditingController();

    final widget = HMBDateTimeField(
      label: placeholder.toCapitalised(),
      initialDateTime: DateTime.now(),
      onChanged: (datetime) {
        controller.text = TimeOfDay.fromDateTime(datetime).format(context);
      },
      showDate: false,
    );
    return PlaceHolderField(
      placeholder: placeholder,
      controller: controller,
      widget: widget,
      getValue: () async => controller.text,
    );
  }

  /// Date placeholder drop list
  PlaceHolderField _buildDatePicker(String placeholder) {
    final controller =
        placeholderFields[placeholder]?.controller ?? TextEditingController();

    final widget = HMBDateTimeField(
      label: placeholder.toCapitalised(),
      initialDateTime: DateTime.now(),
      onChanged: (datetime) {
        controller.text = '${datetime.day}/${datetime.month}/${datetime.year}';
      },
      showTime: false,
    );
    return PlaceHolderField(
      placeholder: placeholder,
      controller: controller,
      widget: widget,
      getValue: () async => controller.text,
    );
  }

  /// Delay Period placeholder drop list
  PlaceHolderField _buildPeriodPicker(String placeholder) {
    final controller =
        placeholderFields[placeholder]?.controller ?? TextEditingController();
    final periods = <String>[
      '10 minutes',
      '15 minutes',
      '20 minutes',
      '30 minutes',
      '45 minutes',
      '1 hour',
      '1.5 hours',
      '2 hours'
    ];
    final widget = DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Delay Period'),
      value: controller.text.isNotEmpty ? controller.text : null,
      items: periods
          .map((period) => DropdownMenuItem<String>(
                value: period,
                child: Text(period),
              ))
          .toList(),
      onChanged: (newValue) {
        setState(() {
          controller.text = newValue!;
        });
      },
    );
    return PlaceHolderField(
      placeholder: placeholder,
      controller: controller,
      widget: widget,
      getValue: () async => controller.text,
    );
  }

  /// Preview window
  Widget _buildPreview() {
    if (_selectedTemplate == null) {
      return Container();
    }

    var previewMessage = _selectedTemplate!.message;

    // Replace the 'signature' placeholder
    previewMessage = previewMessage.replaceAll(
        '{{signature}}', _signature.isNotEmpty ? _signature : '[signature]');

    // Replace other placeholders
    placeholderFields.forEach((key, field) {
      final text = field.controller?.text ?? '';
      previewMessage = previewMessage.replaceAll(
          '{{$key}}', text.isNotEmpty ? text : '[$key]');
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child:
            Text(previewMessage, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }

  @override
  @override
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Message Template'),
        ),
        body: Column(
          children: [
            // The top part with template selection and placeholders
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    HMBDroplist<MessageTemplate>(
                      selectedItem: () async => _selectedTemplate,
                      items: (filter) async => filter == null
                          ? _templates
                          : _templates
                              .where(
                                  (template) => template.title.contains(filter))
                              .toList(),
                      format: (template) => template.title,
                      onChanged: (template) {
                        setState(() {
                          _selectedTemplate = template;
                          _initializePlaceholders();
                          _messageController.text =
                              _selectedTemplate?.message ?? '';
                        });
                      },
                      title: 'Choose a template',
                    ),
                    const SizedBox(height: 20),
                    if (_selectedTemplate != null)
                      Column(
                        children: placeholderFields.values
                            .map((field) => field.widget)
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            // The TabBar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Edit'),
                Tab(text: 'Preview'),
              ],
            ),
            // The TabBarView inside an Expanded widget
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // First Tab: Edit Message
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      controller: _messageController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Edit Message',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedTemplate = _selectedTemplate?.copyWith(
                            message: value,
                          );
                        });
                      },
                    ),
                  ),
                  // Second Tab: Preview Message
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: _buildPreview(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Buttons at the bottom
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                child: const Text('Select'),
                onPressed: () {
                  if (_selectedTemplate != null) {
                    final values = Map<String, String>.from(
                        placeholderFields.map((key, field) {
                      final text = field.controller?.text ?? '';
                      return MapEntry(key, text);
                    }));

                    // Add the 'signature' to values
                    values['signature'] = _signature;

                    final selectedMessageTemplate = SelectedMessageTemplate(
                      template: _selectedTemplate!,
                      values: values,
                    );
                    Navigator.of(context).pop(selectedMessageTemplate);
                  }
                },
              ),
            ],
          ),
        ),
      );

  Future<String?> _getJobValue(String placeholder) async {
    if (_selectedJob != null) {
      switch (placeholder) {
        case 'job_cost':
          return jobCost(_selectedJob!).toString();
        case 'job_description':
          return _selectedJob!.description;
        default:
          return _selectedJob!.summary;
      }
    }
    return null;
  }
}

class SelectedMessageTemplate {
  SelectedMessageTemplate({
    required this.template,
    required this.values,
  });

  final MessageTemplate template;
  final Map<String, String> values;

  String getFormattedMessage() {
    var message = template.message;
    values.forEach((key, value) {
      message = message.replaceAll('{{$key}}', value);
    });
    return message;
  }
}
