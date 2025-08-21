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

import 'package:flutter/material.dart';

/// A small help icon that, when tapped, opens a dialog showing user
/// help content.
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
  /// The tooltip text shown on long press or mouse hover (optional).
  final String tooltip;

  /// Title text shown at the top of the help dialog.
  final String dialogTitle;

  /// The main body widgets of the dialog (e.g. Text, images, etc.).
  final Widget? child;

  final String? helpText;

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

  Future<void> _showHelpDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
    onPressed: () => unawaited(_showHelpDialog(context)),
  );
}

class HelpWrapper extends StatelessWidget {
  final Widget child;
  final Widget? helpChild;
  final String? helpText;
  final String tooltip;
  final String title;

  const HelpWrapper({
    required this.child,
    required this.tooltip,
    required this.title,
    this.helpChild,
    this.helpText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // If the child is already Flexible (Expanded/Flexible), don't wrap it again.
    final rowChild = child is Flexible ? child : Expanded(child: child);

    return Row(
      children: [
        rowChild,
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
}

extension HelpWrapperEx on Widget {
  Widget help(String title, String helpText) => HelpWrapper(
    tooltip: title,
    title: title,
    helpText: helpText,
    child: this,
  );
}
