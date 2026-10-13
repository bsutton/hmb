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
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../dao/dao_message_template.dart';
import '../../dao/dao_site.dart';
import '../../entity/message_template.dart';
import '../widgets/blocking_ui.dart';
import '../widgets/hmb_button.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import 'message_placeholders/noop_source.dart';
import 'message_placeholders/place_holder.dart';
import 'message_placeholders/placeholder_manager.dart';
import 'message_placeholders/source.dart';
import 'message_placeholders/text_holder.dart';
import 'message_placeholders/text_source.dart';
import 'source_context.dart';

final _messagePlaceholderRegExp = RegExp(r'\{\{([^{}]+)\}\}');

List<String> extractMessagePlaceholderNames(String message) {
  final names = <String>[];
  final seen = <String>{};

  for (final match in _messagePlaceholderRegExp.allMatches(message)) {
    final name = match.group(1)!;
    if (seen.add(name)) {
      names.add(name);
    }
  }

  return names;
}

bool isBlankMessageTemplate(MessageTemplate template) {
  if (template.messageType != MessageType.sms) {
    return false;
  }

  return template.title.trim().toLowerCase() == 'blank' ||
      template.message.trim().isEmpty;
}

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
  late final SourceContext _sourceContext;
  var _manager = PlaceHolderManager();
  var _canChooseSite = false;
  String? _validationMessage;

  @override
  Future<void> asyncInitState() async {
    _sourceContext = widget.sourceContext.copy();
    _tabController = TabController(length: 2, vsync: this);
    await BlockingUI().runAndWait(() async {
      await _sourceContext.resolveEntities();
      _canChooseSite =
          _sourceContext.site != null ||
          (_sourceContext.job == null &&
              (await DaoSite().getByCustomer(
                _sourceContext.customer?.id,
              )).isNotEmpty);
      await _loadTemplates();
    }, label: 'Loading message templates');
  }

  Future<void> _loadTemplates() async {
    final templates = await DaoMessageTemplate().getByFilter(null);
    final filtered = await _filterTemplates(templates);
    _selectedTemplate = _selectInitialTemplate(filtered);
    _messageController.text = _selectedTemplate?.message ?? '';
    await _initializePlaceholders(resetExisting: true);

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
          template.messageType != (widget.messageType ?? MessageType.sms)) {
        continue;
      }

      // Persisted wording is intentional, including any explicit site field.
      // Only job/site entry points add an address to otherwise generic SMS.
      final needsSite =
          _sourceContext.job != null || widget.sourceContext.site != null;
      var message = template.message;
      // v225 appended this line even to the built-in blank/signature draft.
      // Recognize only that exact built-in body; preserve customized wording.
      if (template.owner == MessageTemplateOwner.system &&
          template.title.trim().toLowerCase() == 'blank' &&
          const {
            'Site: {{site.address}}',
            '{{signature}}\n\nSite: {{site.address}}',
          }.contains(message.trim())) {
        message = message.replaceFirst(
          RegExp(r'\s*Site: \{\{site.address\}\}$'),
          '',
        );
      }
      final draft = template.copyWith(message: message);
      filtered.add(
        needsSite
            ? draft.copyWith(message: draft.messageWithSiteAddress)
            : draft,
      );
    }
    return filtered;
  }

  MessageTemplate? _selectInitialTemplate(List<MessageTemplate> templates) {
    for (final template in templates) {
      if (isBlankMessageTemplate(template)) {
        return template;
      }
    }

    return templates.isEmpty ? null : templates.first;
  }

  bool _isBaseAvailable(String base) {
    switch (base) {
      case 'text':
      case 'signature':
      case 'delay_period':
      case 'invoice.due_date':
      case 'date.service':
      case 'job_activity.original_date':
        return true;
      case 'job_activity':
        return _sourceContext.jobActivity != null || _sourceContext.job != null;
      case 'job':
        return _sourceContext.job != null;
      case 'site':
        return true;
      case 'customer':
        return _sourceContext.customer != null;
      case 'contact':
        return _sourceContext.contact != null;
      default:
        return false;
    }
  }

  Future<void> _initializePlaceholders({
    bool resetExisting = false,
    int? generation,
  }) async {
    final selectedTemplate = _selectedTemplate;
    if (selectedTemplate == null) {
      placeholders.clear();
      return;
    }

    if (resetExisting) {
      _manager = PlaceHolderManager();
      for (final source in <Source<dynamic>>[
        _manager.customerSource,
        _manager.contactSource,
        _manager.jobSource,
        _manager.siteSource,
        _manager.jobActivitySource,
      ]) {
        source.dependencyChanged(NoopSource(), _sourceContext);
      }
    }
    final names = extractMessagePlaceholderNames(selectedTemplate.message);
    final nextPlaceholders = <String, PlaceHolder<dynamic>>{};

    for (final name in names) {
      final existing = resetExisting ? null : placeholders[name];
      if (existing != null) {
        nextPlaceholders[name] = existing;
        continue;
      }

      var placeholder = await _manager.resolvePlaceholder(name, _sourceContext);
      if (name == 'recipient.name' || name == 'supplier.name') {
        final holder = DefaultHolder(name: name);
        final source = holder.source as TextSource;
        final value = name == 'recipient.name'
            ? _sourceContext.recipientName
            : _sourceContext.supplier?.name ?? '';
        source.text = value;
        source.controller.text = value;
        placeholder = holder;
      } else if (placeholder != null &&
          (!_isBaseAvailable(placeholder.base) ||
              placeholder.base == 'site' && !_canChooseSite)) {
        placeholder = DefaultHolder(name: name);
      }
      if (!mounted ||
          generation != null && generation != _selectionGeneration) {
        return;
      }

      final resolved = placeholder;
      if (resolved != null) {
        /// provide each source with an initial value
        resolved.source.dependencyChanged(NoopSource(), _sourceContext);

        // Listen to source changes and propagate them to
        // other sources and the preview window.
        resolved.listen = (value, reset) async {
          resolved.source.revise(_sourceContext);
          if (reset.site) {
            await BlockingUI().runAndWait(() async {
              await _sourceContext.resolveSite();
              if (mounted) {
                _reset(resolved.source, reset);
                _refreshPreview();
              }
            }, label: 'Loading site address');
          } else {
            _reset(resolved.source, reset);
            _refreshPreview();
          }
        };
        nextPlaceholders[name] = resolved;
      }
    }

    placeholders
      ..clear()
      ..addAll(nextPlaceholders);
  }

  Future<void> _selectTemplate(MessageTemplate? template) async {
    final generation = ++_selectionGeneration;
    _validationMessage = null;
    _selectedTemplate = template;
    _messageController.text = _selectedTemplate?.message ?? '';
    await _initializePlaceholders(resetExisting: true, generation: generation);
    if (!mounted || generation != _selectionGeneration) {
      return;
    }
    setState(() {});
  }

  Future<void> _updateEditedMessage(String value) async {
    final selectedTemplate = _selectedTemplate;
    if (selectedTemplate == null) {
      return;
    }

    final generation = ++_selectionGeneration;
    _validationMessage = null;
    _selectedTemplate = selectedTemplate.copyWith(message: value);
    await _initializePlaceholders(generation: generation);
    if (mounted && generation == _selectionGeneration) {
      setState(() {});
    }
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
    for (final entry in placeholders.entries.toList()) {
      final key = entry.key;
      final text = await entry.value.value();
      previewMessage = previewMessage.replaceAll(
        '{{$key}}',
        text.trim().isNotEmpty ? text : '[Missing: $key]',
      );
    }

    if (previewMessage.contains('{{') || previewMessage.contains('}}')) {
      return const Text('Complete or remove unfinished placeholders in Edit.');
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
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    waitingBuilder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Message Template')),
      body: const SizedBox.shrink(),
    ),
    builder: _buildReady,
  );

  Widget _buildReady(BuildContext context) => Scaffold(
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
                  onChanged: (template) async {
                    await _selectTemplate(template);
                  },
                ),
                if (_selectedTemplate != null) _buildSourceWidgets(),
                const Text(
                  'Fill in missing values, or edit the message to remove '
                  'fields you do not need. The recipient stays unchanged.',
                ),
                if (_validationMessage != null)
                  Text(_validationMessage!, key: const Key('template-error')),
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
                  decoration: const InputDecoration(labelText: 'Edit Message'),
                  onChanged: (value) {
                    unawaited(_updateEditedMessage(value));
                  },
                ),
              ),
              // Second Tab: Preview Message
              Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: FutureBuilderEx(
                    future: _buildPreview(),
                    waitingBuilder: (_) => const SizedBox.shrink(),
                    errorBuilder: (_, error) =>
                        const Text('Unable to preview this message.'),
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
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          HMBCancelButton(
            hint: "Don't select any Template",
            onPressed: () => Navigator.of(context).pop(),
          ),
          HMBButton(
            label: 'Select',
            hint: 'Select the template',
            onPressed: () async {
              if (_selectedTemplate != null) {
                final generation = ++_selectionGeneration;
                await _initializePlaceholders(generation: generation);
                if (!mounted || generation != _selectionGeneration) {
                  return;
                }
                final template = _selectedTemplate!;
                final values = <String, String>{};
                for (final MapEntry(:key, :value)
                    in placeholders.entries.toList()) {
                  final field = value;
                  final fieldValue = await field.value();
                  values.addAll({key: fieldValue});
                }

                final selectedMessageTemplate = SelectedMessageTemplate(
                  template: template,
                  values: values,
                );
                if (!mounted || generation != _selectionGeneration) {
                  return;
                }
                final missing = selectedMessageTemplate.missingValues;
                if (missing.isNotEmpty) {
                  setState(() {
                    _validationMessage =
                        'Complete or remove: '
                        '${missing.join(', ')}';
                  });
                  return;
                }
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
      // Entity selectors must not change the name/context while the phone
      // number still points at the original recipient.
      if (const ['customer', 'contact', 'job'].contains(placeholder.base)) {
        continue;
      }
      final key = placeholder.base == 'text'
          ? placeholder.name
          : placeholder.base;
      if (uniqueWidgets.containsKey(key)) {
        continue;
      }

      final widget = placeholder.source.widget();
      if (widget != null) {
        uniqueWidgets[key] = widget;
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
        placeholder.source.dependencyChanged(source, _sourceContext);
      }
    }
  }
}

class SelectedMessageTemplate {
  final MessageTemplate template;
  final Map<String, String> values;

  SelectedMessageTemplate({required this.template, required this.values});

  List<String> get missingValues {
    final missing = extractMessagePlaceholderNames(
      template.message,
    ).where((name) => (values[name] ?? '').trim().isEmpty).toList();
    var rendered = template.message;
    for (final name in extractMessagePlaceholderNames(template.message)) {
      rendered = rendered.replaceAll('{{$name}}', values[name] ?? '');
    }
    if (rendered.contains('{{') || rendered.contains('}}')) {
      missing.add('unfinished placeholder (edit the message)');
    }
    return missing;
  }

  String getFormattedMessage() {
    if (missingValues.isNotEmpty) {
      throw StateError('Missing template values: ${missingValues.join(', ')}');
    }
    var message = template.message;
    values.forEach((key, value) {
      message = message.replaceAll('{{$key}}', value);
    });
    return message;
  }
}
