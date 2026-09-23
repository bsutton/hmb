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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:strings/strings.dart';

import '../../../util/flutter/hmb_theme.dart';
import '../layout/layout.g.dart';

class HMBTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final String? Function(String? value)? validator;
  final bool autofocus;
  final bool required;
  final TextInputType keyboardType;
  final void Function(String?)? onChanged;
  final String Function(String?)? onPaste;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final bool obscureText;
  final Widget? suffixIcon;
  final List<TextInputFormatter> inputFormatters;
  final Key? fieldKey;
  final int? minLines;
  final int maxLines;

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
    this.obscureText = false,
    super.key,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
    this.inputFormatters = const [],
    this.fieldKey,
    this.minLines,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: <LogicalKeySet, Intent>{
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV):
          const PasteIntent(),
      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV):
          const PasteIntent(), // macOS
    },
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (keyboardType.index == TextInputType.number.index)
          _ZeroValueField(controller: controller, builder: _buildField)
        else
          _buildField(controller, (value) => value),
      ],
    ),
  );

  Widget _buildField(
    TextEditingController editingController,
    String? Function(String?) effectiveValue,
  ) => Actions(
    actions: <Type, Action<Intent>>{
      PasteIntent: CallbackAction<PasteIntent>(
        onInvoke: (intent) => _handlePaste(editingController),
      ),
    },
    child: TextFormField(
      key: fieldKey,
      style: const TextStyle(color: HMBColors.textPrimary),
      enabled: enabled,
      readOnly: !enabled,
      controller: editingController,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged?.call,
      decoration: InputDecoration(labelText: labelText, suffixIcon: suffixIcon),
      validator: (input) {
        final value = effectiveValue(input);
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
          : (context, editable) =>
                buildContextMenu(context, editable, editingController),
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
    TextEditingController editingController,
  ) => AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: [
      ...editableTextState.contextMenuButtonItems.where(
        (item) => item.type != ContextMenuButtonType.paste,
      ),
      ContextMenuButtonItem(
        onPressed: () async {
          await _handlePaste(editingController);
        },
        label: 'Paste',
      ),
    ],
  );

  Future<void> _handlePaste(TextEditingController editingController) async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData == null) {
      return;
    }

    final clipboardText = clipboardData.text;

    final pasteData = onPaste?.call(clipboardText) ?? clipboardText ?? '';

    /// The user may be pasting in part of an email address
    // Get the current selection
    final selection = editingController.selection;

    final text = editingController.text;

    final newText = selection.isValid
        ? text.replaceRange(selection.start, selection.end, pasteData)
        : text + pasteData;

    final newCursorPosition = selection.isValid
        ? selection.start + pasteData.length
        : newText.length;

    editingController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }
}

class PasteIntent extends Intent {
  const PasteIntent();
}

/// Hides a numeric zero while editing without changing its stored value until
/// the user actually types. Validators still see the original zero if the
/// user focuses and immediately saves.
class _ZeroValueField extends StatefulWidget {
  final TextEditingController controller;
  final Widget Function(TextEditingController, String? Function(String?))
  builder;

  const _ZeroValueField({required this.controller, required this.builder});

  @override
  State<_ZeroValueField> createState() => _ZeroValueFieldState();
}

class _ZeroValueFieldState extends State<_ZeroValueField> {
  late final TextEditingController _display;
  var _syncing = false;
  var _hidingZero = false;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _display = TextEditingController.fromValue(widget.controller.value);
    _display.addListener(_displayChanged);
    widget.controller.addListener(_sourceChanged);
  }

  @override
  void didUpdateWidget(covariant _ZeroValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sourceChanged);
      widget.controller.addListener(_sourceChanged);
      _sourceChanged();
    }
  }

  bool _isZero(String text) {
    final number = text.trim().replaceAll(RegExp(r'[$,%\s]'), '');
    return number.isNotEmpty && double.tryParse(number) == 0;
  }

  void _sourceChanged() {
    if (_syncing) {
      return;
    }
    _syncing = true;
    _hidingZero = _focused && _isZero(widget.controller.text);
    _display.value = _hidingZero
        ? TextEditingValue.empty
        : widget.controller.value;
    _syncing = false;
  }

  void _displayChanged() {
    if (_syncing || (_hidingZero && _display.text.isEmpty)) {
      return;
    }
    _hidingZero = false;
    _syncing = true;
    widget.controller.value = _display.value;
    _syncing = false;
  }

  void _focusChanged(bool focused) {
    _focused = focused;
    if (focused || _hidingZero) {
      _sourceChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sourceChanged);
    _display.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: _focusChanged,
    child: widget.builder(
      _display,
      (value) => _hidingZero && (value?.isEmpty ?? true)
          ? widget.controller.text
          : value,
    ),
  );
}
