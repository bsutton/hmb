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

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../entity/message_template.dart';
import '../../dao/dao_message_template.dart';
import '../widgets/hmb_button.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import 'message_placeholders/noop_source.dart';
import 'message_placeholders/place_holder.dart';
import 'message_placeholders/placeholder_manager.dart';
import 'message_placeholders/source.dart';
import 'source_context.dart';

class MessageTemplateDialog extends StatefulWidget {
  final SourceContext sourceContext;
  final MessageType? messageType;

  const MessageTemplateDialog({
    required this.sourceContext,
    this.messageType,
    super.key,
  });

  @override
  _MessageTemplateDialogState createState() => _MessageTemplateDialogState();
}

Future<SelectedMessageTemplate?> showMessageTemplateDialog(
  BuildContext context, {
  required SourceContext sourceContext,
  MessageType? messageType,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => MessageTemplateDialog(
      sourceContext: sourceContext,
      messageType: messageType,
    ),
  ),
);

class _MessageTemplateDialogState extends DeferredState<MessageTemplateDialog>
    with SingleTickerProviderStateMixin {
  List<MessageTemplate> _templates = [];
  MessageTemplate? _selectedTemplate;

  final Map<String, PlaceHolder<dynamic>> placeholders = {};

  late TabController _tabController;
  final _messageController = TextEditingController();
  var _selectionGeneration = 0;

  @override
  Future<void> asyncInitState() async {
    _tabController = TabController(length: 2, vsync: this);
    await widget.sourceContext.resolveEntities();
    await _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final templates = await DaoMessageTemplate().getByFilter(null);
    final filtered = await _filterTemplates(templates);
    if (!mounted) {
      return;
    }
    setState(() {
      _templates = filtered;
    });
  }

  Future<List<MessageTemplate>> _filterTemplates(
    List<MessageTemplate> templates,
  ) async {
    final filtered = <MessageTemplate>[];
    for (final template in templates) {
      if (!template.enabled ||
          (widget.messageType != null &&
              template.messageType != widget.messageType)) {
        continue;
      }
      final names = _extractPlaceholderNames(template.message);
      var canUse = true;
      for (final name in names) {
        final placeholder = await PlaceHolderManager().resolvePlaceholder(
          name,
          widget.sourceContext,
        );
        if (placeholder == null) {
          canUse = false;
          break;
        }
        if (!_isBaseAvailable(placeholder.base)) {
          canUse = false;
          break;
        }
      }
      if (canUse) {
        filtered.add(template);
      }
    }
    return filtered;
  }

  Set<String> _extractPlaceholderNames(String message) {
    final regExp = RegExp(r'\{\{(\w+(?:\.\w+)?)\}\}');
    return regExp.allMatches(message).map((m) => m.group(1)!).toSet();
  }

  bool _isBaseAvailable(String base) {
    switch (base) {
      case 'signature':
      case 'delay_period':
      case 'invoice.due_date':
      case 'date.service':
      case 'job_activity.original_date':
        return true;
      case 'job_activity':
        return widget.sourceContext.jobActivity != null ||
            widget.sourceContext.job != null;
      case 'job':
        return widget.sourceContext.job != null;
      case 'site':
        return widget.sourceContext.site != null;
      case 'customer':
        return widget.sourceContext.customer != null;
      case 'contact':
        return widget.sourceContext.contact != null;
      default:
        return false;
    }
  }

  Future<void> _selectTemplate(MessageTemplate template) async {
    final generation = ++_selectionGeneration;
    _selectedTemplate = template;
    _messageController.text = template.message;
    placeholders.clear();
    setState(() {});

    final resolved = <String, PlaceHolder<dynamic>>{};
    for (final name in _extractPlaceholderNames(template.message)) {
      final placeholder = await PlaceHolderManager().resolvePlaceholder(
        name,
        widget.sourceContext,
      );
      if (!mounted || generation != _selectionGeneration) {
        return;
      }
      if (placeholder == null) {
        continue;
      }

      placeholder.source.dependencyChanged(NoopSource(), widget.sourceContext);
      placeholder.listen = (value, reset) {
        placeholder.source.revise(widget.sourceContext);
        _reset(placeholder.source, reset);
        _refreshPreview();
      };
      resolved[placeholder.name] = placeholder;
    }

    placeholders
      ..clear()
      ..addAll(resolved);
    setState(() {});
  }

  @override
  void dispose() {
    _selectionGeneration++;
    _messageController.dispose();
    _tabController.dispose();
    super.dispose();
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
        '{{$key}}',
        text.isNotEmpty ? text : '[$key]',
      );
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
    appBar: AppBar(title: const Text('Message Template')),
    body: HMBColumn(
      children: [
        // The top part with template selection and placeholders
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: HMBColumn(
              children: [
                HMBDroplist<MessageTemplate>(
                  title: 'Choose a template',
                  selectedItem: () async => _selectedTemplate,
                  items: (filter) async => filter == null
                      ? _templates
                      : _templates
                            .where(
                              (template) => template.title.contains(filter),
                            )
                            .toList(),
                  format: (template) => template.title,
                  onChanged: (template) {
                    if (template != null) {
                      unawaited(_selectTemplate(template));
                    }
                  },
                ),
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
                    future: _buildPreview(),
                    builder: (context, widget) => widget!,
                  ),
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
          HMBButton(
            label: 'Cancel',
            hint: "Don't select any Template",
            onPressed: () => Navigator.of(context).pop(),
          ),
          HMBButton(
            label: 'Select',
            hint: 'Select the template',
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

  Widget _buildSourceWidgets() {
    final uniqueWidgets = <String, Widget>{};

    for (final placeholder in placeholders.values) {
      final widget = placeholder.source.widget();
      if (widget != null) {
        // Use the placeholder base name as a unique key
        uniqueWidgets[placeholder.base] = widget;
      }
    }

    return HMBColumn(children: uniqueWidgets.values.toList());
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
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
  final MessageTemplate template;
  final Map<String, String> values;

  SelectedMessageTemplate({required this.template, required this.values});

  String getFormattedMessage() {
    var message = template.message;
    values.forEach((key, value) {
      message = message.replaceAll('{{$key}}', value);
    });
    return message;
  }
}
