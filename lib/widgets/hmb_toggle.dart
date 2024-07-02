import 'package:flutter/material.dart';

import 'hmb_text_themes.dart';

// ignore: avoid_positional_boolean_parameters
typedef OnChanged = void Function(bool on);

class HMBToggle extends StatefulWidget {
  const HMBToggle({
    required this.label,
    required this.tooltip,
    required this.initialValue,
    required this.onChanged,
    super.key,
  });
  final String label;
  final bool initialValue;
  final String tooltip;
  final OnChanged onChanged;

  @override
  State<HMBToggle> createState() => _HMBToggleState();
}

class _HMBToggleState extends State<HMBToggle> {
  late bool on;
  @override
  void initState() {
    on = widget.initialValue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          HMBTextLabel(widget.label),
          IconButton(
            tooltip: widget.tooltip,
            onPressed: () {
              on = !on;
              widget.onChanged(on);
            },
            iconSize: 25,
            icon: Icon(on ? Icons.toggle_on : Icons.toggle_off),
          ),
        ],
      );
}
