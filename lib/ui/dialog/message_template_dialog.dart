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
import '../widgets/hmb_button.dart';
import '../widgets/select/hmb_droplist.dart';
import 'message_placeholders/place_holder.dart';
import 'message_placeholders/placeholder_manager.dart';

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

  final Map<String, PlaceHolder<dynamic, dynamic>> placeholders = {};

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
          .where((t) => t.message.contains('{{customer.}}'))
          .toList();
    } else if (widget.messageData.supplier != null) {
      return templates
          .where((t) => t.message.contains('{{supplier.}}'))
          .toList();
    } else if (widget.messageData.contact != null) {
      return templates
          .where((t) => t.message.contains('{{contact.}}'))
          .toList();
    }
    return templates;
  }

  Future<void> _initializePlaceholders() async {
    if (_selectedTemplate != null) {
      final regExp = RegExp(r'\{\{(\w+(?:\.\w+)?)\}\}');
      final matches = regExp.allMatches(_selectedTemplate!.message);

      // Get the list of placeholders in the new template
      final newPlaceholders = matches.map((m) => m.group(1)!).toSet();

      // Remove placeholders that are no longer in the new template
      placeholders.entries
          .where((field) => !newPlaceholders.contains(field.key))
          .toList()
          .forEach(placeholders.remove);

      // Add new placeholders or keep existing ones
      for (final name in newPlaceholders) {
        // ignore: inference_failure_on_instance_creation
        final placeholder = await PlaceHolderManager()
            .resolvePlaceholder(name, widget.messageData);

        if (placeholder != null) {
          // final placeholderWidget = placeholder.source.field(widget.messageData);
          // final widget = field(widget.messageData);
          placeholder.listen = (value, reset) {
            _reset(reset);
            _refreshPreview();
          };
          placeholders[placeholder.name] = placeholder;
        }
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
    for (final key in placeholders.keys) {
      final field = placeholders[key];
      final text = await field!.value(widget.messageData);
      previewMessage = previewMessage.replaceAll(
          '{{$key}}', text.isNotEmpty ? text : '[$key]');
    }

    /// the sql message_template
    final lines = previewMessage.split('\n');

    final spans = <TextSpan>[];
    for (final line in lines) {
      spans.add(TextSpan(text: '$line\n'));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: RichText(text: TextSpan(children: spans)),
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
                      title: 'Choose a template',
                      selectedItem: () async => _selectedTemplate,
                      items: (filter) async => filter == null
                          ? _templates
                          : _templates
                              .where(
                                  (template) => template.title.contains(filter))
                              .toList(),
                      format: (template) => template.title,
                      onChanged: (template) async {
                        _selectedTemplate = template;
                        await _initializePlaceholders();
                        _messageController.text =
                            _selectedTemplate?.message ?? '';
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_selectedTemplate != null)
                      Column(
                        children: placeholders.values
                            .where((field) =>
                                field.source.widget(widget.messageData) != null)
                            .map((field) =>
                                field.source.widget(widget.messageData))
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
              HMBButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              HMBButton(
                label: 'Select',
                onPressed: () async {
                  if (_selectedTemplate != null) {
                    final values = <String, String>{};
                    for (final MapEntry(:key, :value) in placeholders.entries) {
                      final field = value;
                      final fieldValue = await field.value(widget.messageData);
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
    for (final placeholder in placeholders.values) {
      if (placeholder.base == scope) {
        placeholder.setValue(null);
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
