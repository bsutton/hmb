import 'package:flutter/material.dart';

import 'layout/hmb_empty.dart';
import 'svg.dart';
import 'text/hmb_text_themes.dart';

class HMBButton extends StatelessWidget {
  const HMBButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      );
}

class HMBButtonPrimary extends StatelessWidget {
  const HMBButtonPrimary({
    required this.label,
    required this.onPressed,
    super.key,
    this.enabled = true,
  })  : svg = null,
        svgColor = null;

  const HMBButtonPrimary.withIcon({
    required this.label,
    required this.svg,
    super.key,
    this.onPressed,
    this.enabled = true,
    this.svgColor,
  });
  final String label;
  final VoidCallback? onPressed;

  final String? svg;

  final Color? svgColor;

  final bool enabled;

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            disabledForegroundColor: Colors.grey.withOpacity(0.38),
            disabledBackgroundColor: Colors.grey.withOpacity(0.12)),
        onPressed: (enabled ? onPressed : null),
        label: HMBTextButton(label),
        icon: svg == null
            ? const HMBEmpty()
            : Svg(svg!, height: 24, width: 24, color: svgColor),
      );
}

class HMBButtonSecondary extends StatelessWidget {
  const HMBButtonSecondary(
      {required this.label, required this.onPressed, super.key});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            disabledForegroundColor: Colors.grey.withOpacity(0.38),
            disabledBackgroundColor: Colors.grey.withOpacity(0.12)),
        child: HMBTextButton(label),
      );
}
