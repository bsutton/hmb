import 'package:flutter/material.dart';

class HMBTooltip extends Tooltip {
  const HMBTooltip({required String hint, required Widget child, super.key})
    : super(
        showDuration: const Duration(seconds: 5),
        message: hint,
        triggerMode: TooltipTriggerMode.longPress,
        child: child,
      );
}
