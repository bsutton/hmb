import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../entity/job.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/widgets.g.dart';
import '../customer/customer_paste_panel.dart';

/// A draft only: persistence belongs to the explicit save callback.
class TaskInstructionDraft {
  final String name;
  final String description;

  const TaskInstructionDraft({required this.name, this.description = ''});
}

class TaskInstructionSuggestion extends TaskInstructionDraft {
  const TaskInstructionSuggestion({required super.name, super.description});
}

typedef AnalyzeTaskInstructions =
    Future<List<TaskInstructionDraft>> Function(String instructions);
typedef SaveTaskInstructions = Future<int> Function(List<TaskInstructionDraft>);

class TaskInstructionsScreen extends StatefulWidget {
  final Job job;
  final AnalyzeTaskInstructions analyze;
  final SaveTaskInstructions save;

  const TaskInstructionsScreen({
    required this.job,
    required this.analyze,
    required this.save,
    super.key,
  });

  @override
  State<TaskInstructionsScreen> createState() => _TaskInstructionsScreenState();
}

class _TaskInstructionsScreenState extends State<TaskInstructionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _drafts = <_DraftEditor>[];
  var _message = '';
  var _reviewing = false;
  var _busy = false;
  var _saved = false;
  String? _error;

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _analyze(String instructions) async {
    if (_busy) {
      return;
    }
    if (instructions.trim().isEmpty) {
      setState(() => _error = 'Paste the customer instructions first.');
      return;
    }
    setState(() {
      _message = instructions;
      _busy = true;
      _error = null;
    });
    try {
      final suggestions = await BlockingUI().runAndWait(
        () => widget.analyze(instructions.trim()),
        label: 'Preparing task suggestions',
      );
      if (!mounted) {
        return;
      }
      for (final draft in _drafts) {
        draft.dispose();
      }
      setState(() {
        _drafts
          ..clear()
          ..addAll(suggestions.map(_DraftEditor.new));
        _reviewing = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not prepare suggestions: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    if (_busy || _saved || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final selected = _drafts.where((draft) => draft.selected).toList();
    if (selected.isEmpty) {
      setState(() => _error = 'Select at least one task to save.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = await BlockingUI().runAndWait(
        () => widget.save([
          for (final draft in selected)
            TaskInstructionDraft(
              name: draft.name.text.trim(),
              description: draft.description.text.trim(),
            ),
        ]),
        label: 'Saving tasks',
      );
      _saved = true;
      if (mounted) {
        Navigator.of(context).pop(count);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save tasks: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Tasks from instructions')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.job.summary),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!),
                      ),
                    if (!_reviewing)
                      CustomerPastePanel(
                        initialMessage: _message,
                        onChanged: (value) => _message = value,
                        helperText:
                            'Paste additional email or SMS instructions. '
                            'Review the proposed tasks before saving.',
                        extractLabel: 'Propose tasks',
                        isExtracting: _busy,
                        onExtract: (text) => unawaited(_analyze(text)),
                      )
                    else ...[
                      const Text('Review tasks'),
                      if (_drafts.isEmpty)
                        const Text('No additional tasks were found.'),
                      for (var index = 0; index < _drafts.length; index++)
                        _buildDraft(_drafts[index], index),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                HMBCancelButton(
                  enabled: !_busy,
                  onPressed: () => Navigator.of(context).pop(),
                  hint: 'Cancel without saving tasks',
                ),
                if (_reviewing) ...[
                  HMBButtonSecondary(
                    label: 'Back',
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _reviewing = false;
                            _error = null;
                          }),
                    hint: 'Review the pasted instructions',
                  ),
                  HMBButtonPrimary(
                    label: 'Save tasks',
                    enabled: !_busy && _drafts.isNotEmpty,
                    onPressed: _save,
                    hint: 'Save the selected tasks',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildDraft(_DraftEditor draft, int index) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          title: Text('Task ${index + 1}'),
          value: draft.selected,
          onChanged: _busy
              ? null
              : (selected) =>
                    setState(() => draft.selected = selected ?? false),
        ),
        if (draft.selected) ...[
          HMBTextField(
            controller: draft.name,
            labelText: 'Task name',
            required: true,
          ),
          HMBTextField(
            controller: draft.description,
            labelText: 'Task description',
            maxLines: 4,
          ),
        ],
      ],
    ),
  );
}

class _DraftEditor {
  final TextEditingController name;
  final TextEditingController description;
  var selected = true;

  _DraftEditor(TaskInstructionDraft draft)
    : name = TextEditingController(text: draft.name),
      description = TextEditingController(text: draft.description);

  void dispose() {
    name.dispose();
    description.dispose();
  }
}
