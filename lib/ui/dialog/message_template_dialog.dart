import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../entity/message_template.dart';
import '../../dao/dao_message_template.dart';
import '../../ui/widgets/async_state.dart';
import '../widgets/hmb_button.dart';
import '../widgets/select/hmb_droplist.dart';
import 'message_placeholders/noop_source.dart';
import 'message_placeholders/place_holder.dart';
import 'message_placeholders/placeholder_manager.dart';
import 'message_placeholders/source.dart';
import 'source_context.dart';

class MessageTemplateDialog extends StatefulWidget {
  const MessageTemplateDialog({required this.sourceContext, super.key});

  final SourceContext sourceContext;

  @override
  _MessageTemplateDialogState createState() => _MessageTemplateDialogState();
}

Future<SelectedMessageTemplate?> showMessageTemplateDialog(BuildContext context,
        {required SourceContext sourceContext}) async =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MessageTemplateDialog(
          sourceContext: sourceContext,
        ),
      ),
    );

class _MessageTemplateDialogState
    extends AsyncState<MessageTemplateDialog>
    with SingleTickerProviderStateMixin {
  List<MessageTemplate> _templates = [];
  MessageTemplate? _selectedTemplate;

  final Map<String, PlaceHolder<dynamic>> placeholders = {};

  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();

  @override
  Future<void> asyncInitState() async {
    _tabController = TabController(length: 2, vsync: this);
    await widget.sourceContext.resolveEntities();
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
    if (widget.sourceContext.job != null) {
      return templates;
    } else if (widget.sourceContext.customer != null) {
      return templates
          .where((t) => t.message.contains('{{customer.}}'))
          .toList();
    } else if (widget.sourceContext.supplier != null) {
      return templates
          .where((t) => t.message.contains('{{supplier.}}'))
          .toList();
    } else if (widget.sourceContext.contact != null) {
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
            .resolvePlaceholder(name, widget.sourceContext);

        if (placeholder != null) {
          /// provide each source with an initial value
          placeholder.source
              .dependencyChanged(NoopSource(), widget.sourceContext);

          // listen to source changes and propergate them to
          // other sources and the preview window.
          placeholder.listen = (value, reset) {
            placeholder.source.revise(widget.sourceContext);
            _reset(placeholder.source, reset);
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

    // Replace  placeholders keys with the actual value
    for (final key in placeholders.keys) {
      final placeholder = placeholders[key];
      final text = await placeholder!.value();
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
                    if (_selectedTemplate != null) _buildSourceWidgets(),
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
                      final fieldValue = await field.value();
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

  Column _buildSourceWidgets() {
    final uniqueWidgets = <String, Widget>{};

    for (final placeholder in placeholders.values) {
      final widget = placeholder.source.widget();
      if (widget != null) {
        // Use the placeholder base name as a unique key
        uniqueWidgets[placeholder.base] = widget;
      }
    }

    return Column(
      children: uniqueWidgets.values.toList(),
    );
  }

  void _refreshPreview() {
    setState(() {});
  }

  void _reset(Source<dynamic> source, ResetFields reset) {
    if (reset.contact) {
      _resetByScope(source, 'contact');
    }
    if (reset.customer) {
      _resetByScope(source, 'customer');
    }

    if (reset.job) {
      _resetByScope(source, 'job');
    }

    if (reset.site) {
      _resetByScope(source, 'site');
    }
  }

  void _resetByScope(Source<dynamic> source, String scope) {
    for (final placeholder in placeholders.values) {
      if (placeholder.base == scope) {
        placeholder.source.dependencyChanged(source, widget.sourceContext);
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
