/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strings/strings.dart';

import '../../../util/hmb_theme.dart';

class HMBTextField extends StatelessWidget {
  /// A customizable text field that supports disabling/enabling input.
  const HMBTextField({
    required this.controller,
    required this.labelText,
    this.keyboardType = TextInputType.text,
    this.required = false,
    this.validator,
    this.focusNode,
    this.onChanged,
    this.onPaste,
    this.enabled = true,
    super.key,
    this.autofocus = false,
    this.leadingSpace = true,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
    this.inputFormatters = const [],
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final String? Function(String? value)? validator;
  final bool autofocus;
  final bool required;
  final bool leadingSpace;
  final TextInputType keyboardType;
  final void Function(String?)? onChanged;
  final String Function(String?)? onPaste;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final Widget? suffixIcon;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: <LogicalKeySet, Intent>{
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV):
          const PasteIntent(),
      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV):
          const PasteIntent(), // macOS
    },
    child: Actions(
      actions: <Type, Action<Intent>>{
        PasteIntent: CallbackAction<PasteIntent>(
          onInvoke: (intent) => _handlePaste(),
        ),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leadingSpace) const SizedBox(height: 16),
          TextFormField(
            style: const TextStyle(color: HMBColors.textPrimary),
            enabled: enabled,
            readOnly: !enabled,
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            onChanged: onChanged?.call,
            decoration: InputDecoration(
              labelText: labelText,
              border: const OutlineInputBorder(),
              suffixIcon: suffixIcon,
            ),
            validator: (value) {
              if (required && enabled && Strings.isBlank(value)) {
                return 'Please enter a $labelText';
              }
              return validator?.call(value);
            },

            // intercept the paste action on mobile so we
            // parse the clipboard data of [onPaste] is
            // passed.
            contextMenuBuilder: onPaste == null
                ? defaultContextMenuBuilder
                : buildContextMenu,
          ),
        ],
      ),
    ),
  );

  Widget defaultContextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        SystemContextMenu.isSupported(context)) {
      return SystemContextMenu.editableText(
        editableTextState: editableTextState,
      );
    }
    return AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }

  Widget buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) => AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: [
      ...editableTextState.contextMenuButtonItems.where(
        (item) => item.type != ContextMenuButtonType.paste,
      ),
      ContextMenuButtonItem(
        onPressed: () async {
          await _handlePaste();
        },
        label: 'Paste',
      ),
    ],
  );

  Future<void> _handlePaste() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData == null) {
      return;
    }

    final clipboardText = clipboardData.text;

    final pasteData = onPaste?.call(clipboardText) ?? clipboardText ?? '';

    /// The user may be pasting in part of an email address
    // Get the current selection
    final selection = controller.selection;

    final text = controller.text;

    final newText = selection.isValid
        ? text.replaceRange(selection.start, selection.end, pasteData)
        : text + pasteData;

    final newCursorPosition = selection.isValid
        ? selection.start + pasteData.length
        : newText.length;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }
}

class PasteIntent extends Intent {
  const PasteIntent();
}
