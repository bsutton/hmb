import 'package:flutter/material.dart';

/// A small help icon that, when tapped, opens a dialog showing user help content.
///
/// Usage example:
///
/// Row(
///   children: [
///     Expanded(
///       child: TextField(
///         decoration: InputDecoration(labelText: 'Your Field'),
///       ),
///     ),
///     HelpIconButton(
///       tooltip: 'Explain this field',
///       dialogTitle: 'Field Help',
///       dialogContent: Column(
///         crossAxisAlignment: CrossAxisAlignment.start,
///         children: [
///           Text('This field is used for XYZ.'),
///           SizedBox(height: 10),
///           Text('Further explanation or tips here.'),
///         ],
///       ),
///     ),
///   ],
/// )
///
class HelpButton extends StatelessWidget {
  const HelpButton({
    required this.child,
    super.key,
    this.tooltip = 'Help',
    this.dialogTitle = 'Help',
  }) : helpText = null;

  const HelpButton.text({
    required this.helpText,
    super.key,
    this.tooltip = 'Help',
    this.dialogTitle = 'Help',
  }) : child = null;

  /// The tooltip text shown on long press or mouse hover (optional).
  final String tooltip;

  /// Title text shown at the top of the help dialog.
  final String dialogTitle;

  /// The main body widgets of the dialog (e.g. Text, images, etc.).
  final Widget? child;

  final String? helpText;

  Future<void> _showHelpDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(dialogTitle),
            content: child ?? Text(helpText!, textAlign: TextAlign.start),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.help_outline),
    tooltip: tooltip,
    onPressed: () async => _showHelpDialog(context),
  );
}

class HelpWrapper extends StatelessWidget {
  const HelpWrapper({
    required this.child,
    required this.tooltip,
    required this.title,
    this.helpChild,
    this.helpText,
    super.key,
  });

  final Widget child;
  final Widget? helpChild;
  final String? helpText;
  final String tooltip;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: child),
      if (helpChild != null)
        HelpButton(tooltip: tooltip, dialogTitle: title, child: helpChild)
      else
        HelpButton.text(
          tooltip: tooltip,
          dialogTitle: title,
          helpText: helpText,
        ),
    ],
  );
}

extension HelpWrapperEx on Widget {
  Widget help(String title, String helpText) => HelpWrapper(
    tooltip: title,
    title: title,
    helpText: helpText,
    child: this,
  );
}
