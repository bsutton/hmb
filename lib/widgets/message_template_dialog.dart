import 'package:flutter/material.dart';

import '../../entity/message_template.dart';
import '../dao/dao_message_template.dart';

class MessageTemplateDialog extends StatefulWidget {
  const MessageTemplateDialog({
    required this.customerId,
    required this.jobId,
    super.key,
  });
  final int customerId;
  final int jobId;

  @override
  // ignore: library_private_types_in_public_api
  _MessageTemplateDialogState createState() => _MessageTemplateDialogState();
}

Future<SelectedMessageTemplate?> showMessageTemplateDialog(
    BuildContext context) async {
  final result = await showDialog<SelectedMessageTemplate>(
    context: context,
    builder: (context) =>
        const MessageTemplateDialog(customerId: 123, jobId: 456),
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

class _MessageTemplateDialogState extends State<MessageTemplateDialog> {
  List<MessageTemplate> _templates = [];
  MessageTemplate? _selectedTemplate;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final dao = DaoMessageTemplate();
    final templates = await dao.getByFilter(null);
    setState(() {
      _templates = templates.where((template) => template.enabled).toList();
    });
  }

  Widget _buildInputField(String placeholder) {
    if (!_controllers.containsKey(placeholder)) {
      _controllers[placeholder] = TextEditingController();
    }

    return TextFormField(
      controller: _controllers[placeholder],
      decoration: InputDecoration(labelText: placeholder),
    );
  }

  Widget _buildTimePicker(String placeholder) {
    var selectedTime = TimeOfDay.now();

    return ListTile(
      title: Text(placeholder),
      subtitle: Text(_controllers[placeholder]?.text ?? 'Select Time'),
      onTap: () async {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: selectedTime,
        );
        if (pickedTime != null) {
          setState(() {
            selectedTime = pickedTime;
            _controllers[placeholder]?.text = selectedTime.format(context);
          });
        }
      },
    );
  }

  Widget _buildPreview() {
    if (_selectedTemplate == null) {
      return Container();
    }

    var previewMessage = _selectedTemplate!.message;
    _controllers.forEach((key, controller) {
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
            DropdownButton<MessageTemplate>(
              value: _selectedTemplate,
              hint: const Text('Choose a template'),
              isExpanded: true,
              items: _templates
                  .map((template) => DropdownMenuItem<MessageTemplate>(
                        value: template,
                        child: Text(template.title),
                      ))
                  .toList(),
              onChanged: (template) {
                setState(() {
                  _selectedTemplate = template;
                  _controllers.clear();

                  if (_selectedTemplate != null) {
                    final regExp = RegExp(r'\{\{(\w+)\}\}');
                    final matches =
                        regExp.allMatches(_selectedTemplate!.message);

                    for (final match in matches) {
                      final placeholder = match.group(1)!;
                      if (placeholder.contains('time')) {
                        _controllers[placeholder] = TextEditingController();
                      } else {
                        _controllers[placeholder] = TextEditingController();
                      }
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 20),
            if (_selectedTemplate != null)
              Column(
                children: _controllers.keys.map((key) {
                  if (key.contains('time')) {
                    return _buildTimePicker(key);
                  } else {
                    return _buildInputField(key);
                  }
                }).toList(),
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
                  values: _controllers
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
