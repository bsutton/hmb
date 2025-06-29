/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../util/hmb_theme.dart';
import 'color_ex.dart';
import 'layout/hmb_empty.dart';
import 'svg.dart';

/// A generic HMB button with optional hint shown on long press.
class HMBButton extends StatelessWidget {
  const HMBButton({
    required this.label,
    required this.onPressed,
    required this.hint,
    this.enabled = true,
    super.key,
    this.color = HMBColors.buttonLabel,
  }) : icon = null;

  const HMBButton.withIcon({
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.hint,
    this.enabled = true,
    this.color = HMBColors.buttonLabel,
    super.key,
  });

  final String label;
  final Icon? icon;
  final VoidCallback onPressed;
  final bool enabled;
  final Color color;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? ElevatedButton.icon(
            onPressed: enabled ? onPressed : null,
            label: Text(label, style: TextStyle(color: color)),
            icon: icon,
          )
        : ElevatedButton(
            onPressed: enabled ? onPressed : null,
            child: Text(label, style: TextStyle(color: color)),
          );

    return Tooltip(
      message: hint,
      triggerMode: TooltipTriggerMode.longPress,
      child: button,
    );
  }
}

/// A primary-styled button with optional SVG icon and hint on long press.
class HMBButtonPrimary extends StatelessWidget {
  const HMBButtonPrimary({
    required this.label,
    required this.onPressed,
    required this.hint,
    super.key,
    this.enabled = true,
  }) : svg = null,
       svgColor = null;

  const HMBButtonPrimary.withSvg({
    required this.label,
    required this.svg,
    required this.hint,
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
  final String hint;

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        disabledForegroundColor: (Colors.grey[500]!).withSafeOpacity(0.38),
        disabledBackgroundColor: (Colors.grey[500]!).withSafeOpacity(0.12),
      ),
      onPressed: enabled ? onPressed : null,
      label: Text(label, style: const TextStyle(color: HMBColors.buttonLabel)),
      icon: svg == null
          ? const HMBEmpty()
          : Svg(svg!, height: 24, width: 24, color: svgColor),
    );

    return Tooltip(
      message: hint,
      triggerMode: TooltipTriggerMode.longPress,
      child: btn,
    );
  }
}

/// A secondary-styled button with hint on long press.
class HMBButtonSecondary extends StatelessWidget {
  const HMBButtonSecondary({
    required this.label,
    required this.onPressed,
    required this.hint,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        disabledForegroundColor: (Colors.grey[500]!).withSafeOpacity(0.38),
        disabledBackgroundColor: (Colors.grey[500]!).withSafeOpacity(0.12),
      ),
      child: Text(label, style: const TextStyle(color: HMBColors.buttonLabel)),
    );

    return Tooltip(
      message: hint,
      triggerMode: TooltipTriggerMode.longPress,
      child: btn,
    );
  }
}

/// A link-style button that launches a URL and shows a hint on long press.
class HMBLinkButton extends StatelessWidget {
  const HMBLinkButton({
    required this.label,
    required this.link,
    required this.hint,
    super.key,
  });

  final String label;
  final String link;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final btn = TextButton(
      onPressed: () => unawaited(_launchURL(link)),
      child: Text(label, style: const TextStyle(color: Colors.blue)),
    );

    return Tooltip(
      message: hint,
      triggerMode: TooltipTriggerMode.longPress,
      child: btn,
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri);
  }
}
