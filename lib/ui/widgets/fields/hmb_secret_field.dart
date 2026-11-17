import 'package:material_ui/material_ui.dart';

import 'hmb_text_field.dart';

/// A credential field that reveals its value only on explicit request.
class HMBSecretField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final bool required;
  final bool enabled;
  final Widget? suffixIcon;

  const HMBSecretField({
    required this.controller,
    required this.labelText,
    this.required = false,
    this.enabled = true,
    this.suffixIcon,
    super.key,
  });

  @override
  State<HMBSecretField> createState() => _HMBSecretFieldState();
}

class _HMBSecretFieldState extends State<HMBSecretField> {
  var _visible = false;

  @override
  void didUpdateWidget(covariant HMBSecretField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller || !widget.enabled) {
      _visible = false;
    }
  }

  @override
  Widget build(BuildContext context) => HMBTextField(
    controller: widget.controller,
    labelText: widget.labelText,
    required: widget.required,
    enabled: widget.enabled,
    keyboardType: TextInputType.visiblePassword,
    obscureText: !_visible,
    autocorrect: false,
    enableSuggestions: false,
    suffixIcon: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.suffixIcon != null) widget.suffixIcon!,
        IconButton(
          tooltip: '${_visible ? 'Hide' : 'Show'} ${widget.labelText}',
          icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
          onPressed: widget.enabled
              ? () => setState(() => _visible = !_visible)
              : null,
        ),
      ],
    ),
  );
}
