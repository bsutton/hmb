import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../entity/message_template.dart';
import '../../dao/dao_message_template.dart';
import '../../entity/contact.dart';
import '../../entity/customer.dart';
import '../../entity/invoice.dart';
import '../../entity/job.dart';
import '../../entity/site.dart';
import '../../entity/supplier.dart';
import '../../ui/widgets/async_state.dart';
import '../../util/local_date.dart';
import '../../util/local_time.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/text/hmb_text_themes.dart';
import 'message_placeholders/place_holder.dart';

class MessageTemplateDialog extends StatefulWidget {
  const MessageTemplateDialog({required this.messageData, super.key});

  final MessageData messageData;

  @override
  _MessageTemplateDialogState createState() => _MessageTemplateDialogState();
}

class MessageData {
  MessageData({
    this.customer,
    this.job,
    this.contact,
    this.supplier,
    this.site,
    this.invoice,
    this.delayPeriod,
    this.originalDate,
    this.appointmentDate,
    this.appointmentTime,
  });
  Customer? customer;
  Job? job;
  Contact? contact;
  Supplier? supplier;
  Site? site;
  Invoice? invoice;
  String? delayPeriod;
  LocalDate? originalDate;
  LocalDate? appointmentDate;
  LocalTime? appointmentTime;
}

Future<SelectedMessageTemplate?> showMessageTemplateDialog(BuildContext context,
        {required MessageData messageData}) async =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MessageTemplateDialog(
          messageData: messageData,
        ),
      ),
    );

class _MessageTemplateDialogState
    extends AsyncState<MessageTemplateDialog, void>
    with SingleTickerProviderStateMixin {
  List<MessageTemplate> _templates = [];
  MessageTemplate? _selectedTemplate;

  final Map<String, PlaceHolderField<dynamic>> placeholderFields = {};

  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();

  @override
  Future<void> asyncInitState() async {
    _tabController = TabController(length: 2, vsync: this);
    await _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final templates = await DaoMessageTemplate().getByFilter(null);
    setState(() {
      _templates = _filterTemplates(templates);
    });
  }

  List<MessageTemplate> _filterTemplates(List<MessageTemplate> templates) {
    // Filter based on the screen type
    if (widget.messageData.job != null) {
      return templates;
    } else if (widget.messageData.customer != null) {
      return templates
          .where((t) => t.message.contains('{{customer_}}'))
          .toList();
    } else if (widget.messageData.supplier != null) {
      return templates
          .where((t) => t.message.contains('{{supplier_}}'))
          .toList();
    } else if (widget.messageData.contact != null) {
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
      placeholderFields.entries
          .where((field) => !newPlaceholders.contains(field.key))
          .toList()
          .forEach(placeholderFields.remove);

      // Add new placeholders or keep existing ones
      for (final name in newPlaceholders) {
        // ignore: inference_failure_on_instance_creation
        final placeholder = PlaceHolder.fromName(name);

        // final field = placeholder.field(widget.messageData);
        // field.placeholder.listen = (value, reset) {
        //   _reset(reset);
        //   _refreshPreview();
        // };
        // placeholderFields[field.placeholder.name] = field;
      }
    }
  }

  /// Preview window
  Future<Widget> _buildPreview() async {
    if (_selectedTemplate == null) {
      return Container();
    }

    var previewMessage = _selectedTemplate!.message;

    // Replace other placeholders
    for (final key in placeholderFields.keys) {
      final field = placeholderFields[key];
      final text = await field!.getValue(widget.messageData);
      previewMessage = previewMessage.replaceAll(
          '{{$key}}', text.isNotEmpty ? text : '[$key]');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: HMBTextBody(previewMessage),
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
                            .where((field) => field.widget != null)
                            .map((field) => field.widget)
                            .whereType<Widget>()
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
                        child: FutureBuilderEx(
                            // ignore: discarded_futures
                            future: _buildPreview(),
                            builder: (context, widget) => widget!)),
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
                onPressed: () async {
                  if (_selectedTemplate != null) {
                    final values = <String, String>{};
                    for (final MapEntry(:key, :value)
                        in placeholderFields.entries) {
                      final field = value;
                      final fieldValue =
                          await field.getValue(widget.messageData);
                      values.addAll({key: fieldValue});
                    }

                    final selectedMessageTemplate = SelectedMessageTemplate(
                      template: _selectedTemplate!,
                      values: values,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop(selectedMessageTemplate);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      );

  void _refreshPreview() {
    setState(() {});
  }

  void _reset(ResetFields reset) {
    if (reset.contact) {
      _resetByScope('contact');
    }
    if (reset.customer) {
      _resetByScope('customer');
    }

    if (reset.job) {
      _resetByScope('job');
    }

    if (reset.site) {
      _resetByScope('site');
    }
  }

  void _resetByScope(String scope) {
    for (final placeholderField in placeholderFields.values) {
      if (placeholderField.placeholder.key == scope) {
        placeholderField.placeholder.setValue(null);
      }
    }
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
