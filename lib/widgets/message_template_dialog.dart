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
  PlaceHolderField({
    required this.placeholder,
    required this.widget,
    this.controller,
  });

  final String placeholder;
  final TextEditingController? controller;
  final Widget widget;
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
}) async {
  final result = await showDialog<SelectedMessageTemplate>(
    context: context,
    builder: (context) => MessageTemplateDialog(
      customer: customer,
      job: job,
      supplier: supplier,
      contact: contact,
    ),
  );

  if (result != null) {
    final selectedTemplate = result.template;
    final values = result.values;
    final formattedMessage = result.getFormattedMessage();

    print('Selected Template: ${selectedTemplate.title}');
    print('Values: $values');
    print('Formatted Message: $formattedMessage');
  }
  return result;
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
    placeholderFields.clear();
    if (_selectedTemplate != null) {
      final regExp = RegExp(r'\{\{(\w+)\}\}');
      final matches = regExp.allMatches(_selectedTemplate!.message);

      for (final match in matches) {
        final placeholder = match.group(1)!;
        placeholderFields[placeholder] = _buildPlaceHolderField(placeholder);
      }
    }
  }

  PlaceHolderField _buildPlaceHolderField(String placeholder) {
    if (placeholder.contains('time')) {
      return _buildTimePicker(placeholder);
    } else if (placeholder.contains('date')) {
      return _buildDatePicker(placeholder);
    } else if (placeholder == 'delay_period') {
      return _buildPeriodPicker(placeholder);
    } else if (placeholder == 'customer_name') {
      return _buildCustomerDroplist(placeholder);
    } else if (placeholder == 'job_address') {
      return _buildSiteDroplist(placeholder);
    } else if (placeholder == 'contact_name') {
      return _buildContactDroplist(placeholder);
    }

    // Default TextFormField for other placeholders
    final controller = TextEditingController();
    final widget = TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: placeholder.toCapitalised()),
    );
    return PlaceHolderField(
      placeholder: placeholder,
      controller: controller,
      widget: widget,
    );
  }

  PlaceHolderField _buildCustomerDroplist(String placeholder) {
    final controller = TextEditingController();
    final widget = HMBDroplist<Customer>(
      title: 'Select Customer',
      selectedItem: () async => _selectedCustomer,
      items: (filter) async => DaoCustomer().getByFilter(filter),
      format: (customer) => customer.name,
      onChanged: (customer) {
        setState(() {
          _selectedCustomer = customer;
          controller.text = customer?.name ?? '';
        });
      },
    );
    return PlaceHolderField(
      placeholder: placeholder,
      controller: controller,
      widget: widget,
    );
  }

  PlaceHolderField _buildSiteDroplist(String placeholder) {
    final controller = TextEditingController();
    final Widget droplist;
    droplist = HMBDroplist<Site>(
      title: 'Select Job Address',
      selectedItem: () async => _selectedSite,
      items: (filter) async {
        if (widget.job != null) {
          final site = await DaoSite().getById(widget.job!.siteId);
          return [site!];
        } else {
          final customer = await DaoCustomer().getById(widget.job!.customerId);
          return DaoSite().getByFilter(customer, filter);
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
    );
  }

  PlaceHolderField _buildContactDroplist(String placeholder) {
    final controller = TextEditingController();
    final Widget droplist;
    droplist = HMBDroplist<Contact>(
      title: 'Select Contact',
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
    );
  }

  PlaceHolderField _buildTimePicker(String placeholder) {
    final controller = TextEditingController();
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
    );
  }

  PlaceHolderField _buildDatePicker(String placeholder) {
    final controller = TextEditingController();
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
    );
  }

  PlaceHolderField _buildPeriodPicker(String placeholder) {
    final controller = TextEditingController();
    final periods = <String>['15 minutes', '30 minutes', '1 hour', '2 hours'];
    final widget = DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Delay Period'),
      value: controller.text.isEmpty ? null : controller.text,
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
    );
  }

  Widget _buildPreview() {
    if (_selectedTemplate == null) {
      return Container();
    }

    var previewMessage = _selectedTemplate!.message;
    placeholderFields.forEach((key, field) {
      final text = field.controller?.text ?? '';
      previewMessage =
          previewMessage.replaceAll('{{$key}}', text.isEmpty ? '[$key]' : text);
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HMBDroplist<MessageTemplate>(
                selectedItem: () async => _selectedTemplate,
                items: (filter) async => filter == null
                    ? _templates
                    : _templates
                        .where((template) => template.message.contains(filter))
                        .toList(),
                format: (template) => template.title,
                onChanged: (template) {
                  setState(() {
                    _selectedTemplate = template;
                    _initializePlaceholders();
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
              const SizedBox(height: 20),
              _buildPreview(),
            ],
          ),
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
                  values: placeholderFields.map((key, field) {
                    final text = field.controller?.text ?? '';
                    return MapEntry(key, text);
                  }),
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
