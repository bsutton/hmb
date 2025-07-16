/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import 'hmb_tooltip.dart';

enum HMBIconButtonSize { small, standard, large }

/// Displays an icon button with configurable size and tooltip shown on long press.
class HMBIconButton extends StatefulWidget {
  const HMBIconButton({
    required this.onPressed,
    required this.hint,
    required this.icon,
    this.enabled = true,
    this.showBackground = true,
    this.size = HMBIconButtonSize.standard,
    super.key,
  });

  final Future<void> Function()? onPressed;
  final bool enabled;
  final Icon icon;
  final String? hint;
  final HMBIconButtonSize size;
  final bool showBackground;

  @override
  _HMBIconButtonState createState() => _HMBIconButtonState();
}

class _HMBIconButtonState extends State<HMBIconButton> {
  final _tooltipKey = GlobalKey<TooltipState>();

  // Define the size for each button size variant
  double get _buttonSize {
    switch (widget.size) {
      case HMBIconButtonSize.small:
        return 32;
      case HMBIconButtonSize.large:
        return 64;
      case HMBIconButtonSize.standard:
        return 48;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: () {
      if (widget.hint != null && widget.hint!.isNotEmpty) {
        _tooltipKey.currentState?.ensureTooltipVisible();
      }
    },
    behavior: HitTestBehavior.opaque,
    child: HMBTooltip(
      key: _tooltipKey,
      hint: widget.hint ?? '',
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: (widget.showBackground)
            ? CircleAvatar(
                backgroundColor: Colors.lightBlue,
                radius: _buttonSize / 2,
                child: IconButton(
                  icon: widget.icon,
                  onPressed: widget.enabled ? widget.onPressed : null,
                  iconSize: _buttonSize * 0.5,
                ),
              )
            : IconButton(
                icon: widget.icon,
                onPressed: widget.enabled ? widget.onPressed : null,
                iconSize: _buttonSize * 0.5,
              ),
      ),
    ),
  );
}
