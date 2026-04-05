import 'package:flutter/material.dart';

class PlasterboardEditorToolAction {
  final String id;
  final String label;
  final String helpText;
  final bool enabled;
  final bool selected;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed;

  const PlasterboardEditorToolAction({
    required this.id,
    required this.label,
    required this.helpText,
    this.enabled = true,
    this.selected = false,
    this.icon,
    this.iconWidget,
    this.onPressed,
  }) : assert(icon != null || iconWidget != null);
}
