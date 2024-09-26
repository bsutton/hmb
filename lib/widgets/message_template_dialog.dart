import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../entity/message_template.dart';
import '../dao/dao_contact.dart';
import '../dao/dao_customer.dart';
import '../dao/dao_message_template.dart';
import '../dao/dao_site.dart';
import '../entity/contact.dart';
import '../entity/customer.dart';
import '../entity/job.dart';
import '../entity/site.dart';
import '../entity/supplier.dart';
import 'async_state.dart';
import 'hmb_date_time_picker.dart';
import 'hmb_droplist.dart';

class PlaceHolderField {
  PlaceHolderField(this.placeholder, this.controller, this.picker);
  String placeholder;
  ValueNotifier<TextEditingValue>? controller;
  Widget picker;
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

Future<SelectedMessageTemplate?> showMessageTemplateDialog(BuildContext context,
    {Customer? customer,
    Job? job,
    Contact? contact,
    Supplier? supplier}) async {
  final result = await showDialog<SelectedMessageTemplate>(
    context: context,
    builder: (context) =>
        MessageTemplateDialog(customer: customer, job: job, supplier: supplier),
  );

  if (result != null) {
    final selectedTemplate = result.template;
    final values = result.values;
    final formattedMessage = result.getFormattedMessage();

    print('Selected Template: ${selectedTemplate.title}');
    print('Values: $values');
    print('Formatted Message: $formattedMessage');
  }
  return null;
}

class _MessageTemplateDialogState
    extends AsyncState<MessageTemplateDialog, void> {
  List<MessageTemplate> _templates = [];
  MessageTemplate? _selectedTemplate;

  final Map<String, PlaceHolderField> placeholderFields = {};
  Customer? _selectedCustomer;
  Site? _selectedSite;
  Contact? _selectedContact;

  @override
  Future<void> asyncInitState() async {
    await _loadTemplates();
    if (widget.job != null) {
      await _loadJobDetails(widget.job!);
    }
  }

  Future<void> _loadTemplates() async {
    // Fetch templates based on the screen (Job, Customer, Supplier, or Contact)
    final templates = await DaoMessageTemplate().getByFilter(null);
    setState(() {
      _templates = _filterTemplates(templates);
    });
  }

  Future<void> _loadJobDetails(Job job) async {
    // Load customer and site details for the job
    final customer = await DaoCustomer().getById(job.customerId);
    final site = await DaoSite().getById(job.siteId);
    _selectedCustomer = customer;
    _selectedSite = site;
    _selectedContact = job.contactId != null
        ? await DaoContact().getById(job.contactId).then((c) => c)
        : null;
    setState(() {});
  }

  List<MessageTemplate> _filterTemplates(List<MessageTemplate> templates) {
    // Filter based on the screen type (job, customer, supplier, contact)
    if (widget.job != null) {
      return templates.where((t) => t.message.contains('{{job_')).toList();
    } else if (widget.customer != null) {
      return templates.where((t) => t.message.contains('{{customer_')).toList();
    } else if (widget.supplier != null) {
      return templates.where((t) => t.message.contains('{{supplier_')).toList();
    } else if (widget.contact != null) {
      return templates.where((t) => t.message.contains('{{contact_')).toList();
    }
    return templates;
  }

  Widget _buildPlaceholderField(String placeholder) {
    if (!placeholderFields.containsKey(placeholder)) {
      placeholderFields[placeholder] = TextEditingController();
    }

    return buildPlaceHolderPicker(placeholder);
  }

  PlaceHolderField buildPlaceHolderPicker(String placeholder) {
    if (placeholder.contains('time')) {
      return _buildTimePicker(placeholder);
    } else if (placeholder.contains('date')) {
      return _buildDatePicker(placeholder);
    } else if (placeholder == 'delay_period') {
      return _buildPeriodPicker(placeholder);
    } else if (placeholder == 'customer_name' && _selectedCustomer != null) {
      return HMBDroplist(
          title: 'Customer',
          selectedItem: () async => _selectedCustomer,
          items: (filter) async => DaoCustomer().getByFilter(filter),
          onChanged: (customer) => _selectedCustomer = customer,
          format: (customer) => customer.name);
    } else if (placeholder == 'site' && _selectedSite != null) {
      return TextFormField(
        controller: placeholderFields[placeholder]!
          ..text = _selectedSite!.address,
        decoration: const InputDecoration(labelText: 'Site'),
      );
    } else if (placeholder == 'contact_name' && _selectedContact != null) {
      return TextFormField(
        controller: placeholderFields[placeholder]!
          ..text = _selectedContact!.fullname,
        decoration: const InputDecoration(labelText: 'Contact Name'),
      );
    }

    // Default TextFormField for other placeholders
    return TextFormField(
      controller: placeholderFields[placeholder],
      decoration: InputDecoration(labelText: placeholder.toCapitalised()),
    );
  }

  PlaceHolderField _buildTimePicker(String placeholder) {
    var selectedTime = TimeOfDay.now();

    final widget = HMBDateTimeField(
        label: placeholder,
        initialDateTime: DateTime.now(),
        onChanged: (datetime) => _selectedTime = datetime,
        showDate: false);

    return PlaceHolderField(placeholder, null, widget);

    // ListTile(
    //   title: Text(placeholder),
    //   subtitle: Text(placeholderFields[placeholder]?.text ?? 'Select Time'),
    //   onTap: () async {
    //     final pickedTime = await showTimePicker(
    //       context: context,
    //       initialTime: selectedTime,
    //     );
    //     if (pickedTime != null) {
    //       setState(() {
    //         selectedTime = pickedTime;
    //         placeholderFields[placeholder]?.text = selectedTime.format(context);
    //       });
    //     }
    //   },
    // );
  }

    PlaceHolderField _buildDatePicker(String placeholder) {
    var selectedTime = TimeOfDay.now();

    final widget = HMBDateTimeField(
        label: placeholder,
        initialDateTime: DateTime.now(),
        onChanged: (datetime) => selectedDate = datetime,
        showDate: false);

    return PlaceHolderField(placeholder, null, widget);

    // ListTile(
    //   title: Text(placeholder),
    //   subtitle: Text(placeholderFields[placeholder]?.text ?? 'Select Time'),
    //   onTap: () async {
    //     final pickedTime = await showTimePicker(
    //       context: context,
    //       initialTime: selectedTime,
    //     );
    //     if (pickedTime != null) {
    //       setState(() {
    //         selectedTime = pickedTime;
    //         placeholderFields[placeholder]?.text = selectedTime.format(context);
    //       });
    //     }
    //   },
    // );
  }

  Widget _buildDatePicker(String placeholder) {
    var selectedDate = DateTime.now();
    return ListTile(
      title: Text(placeholder),
      subtitle: Text(placeholderFields[placeholder]?.text ?? 'Select Date'),
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (pickedDate != null) {
          setState(() {
            selectedDate = pickedDate;
            placeholderFields[placeholder]?.text =
                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
          });
        }
      },
    );
  }

  Widget _buildPeriodPicker(String placeholder) {
    final periods = <String>['15 minutes', '30 minutes', '1 hour', '2 hours'];
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Delay Period'),
      value: placeholderFields[placeholder]?.text,
      items: periods
          .map((period) => DropdownMenuItem<String>(
                value: period,
                child: Text(period),
              ))
          .toList(),
      onChanged: (newValue) {
        setState(() {
          placeholderFields[placeholder]?.text = newValue!;
        });
      },
    );
  }

  Widget _buildPreview() {
    if (_selectedTemplate == null) {
      return Container();
    }

    var previewMessage = _selectedTemplate!.message;
    placeholderFields.forEach((key, controller) {
      previewMessage = previewMessage.replaceAll(
          '{{$key}}', controller.text.isEmpty ? '[$key]' : controller.text);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview:', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Text(previewMessage, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Select Message Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HMBDroplist<MessageTemplate>(
              selectedItem: () async => _selectedTemplate,
              items: (filter) async => _templates,
              format: (template) => template.title,
              onChanged: (template) {
                setState(() {
                  _selectedTemplate = template;
                  placeholderFields.clear();
                  if (_selectedTemplate != null) {
                    final regExp = RegExp(r'\{\{(\w+)\}\}');
                    final matches =
                        regExp.allMatches(_selectedTemplate!.message);

                    for (final match in matches) {
                      final placeholder = match.group(1)!;
                      placeholderFields[placeholder] = TextEditingController();
                    }
                  }
                });
              },
              title: 'Choose a template',
            ),
            const SizedBox(height: 20),
            if (_selectedTemplate != null)
              Column(
                children:
                    placeholderFields.keys.map(_buildPlaceholderField).toList(),
              ),
            const SizedBox(height: 20),
            _buildPreview(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_selectedTemplate != null) {
                final selectedMessageTemplate = SelectedMessageTemplate(
                  template: _selectedTemplate!,
                  values: placeholderFields
                      .map((key, controller) => MapEntry(key, controller.text)),
                );
                Navigator.of(context).pop(selectedMessageTemplate);
              }
            },
            child: const Text('Select'),
          ),
        ],
      );
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
