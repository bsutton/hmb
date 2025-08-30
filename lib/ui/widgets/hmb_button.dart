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
import 'package:url_launcher/url_launcher.dart';

import '../../util/flutter/hmb_theme.dart';
import 'color_ex.dart';
import 'hmb_tooltip.dart';
import 'layout/hmb_empty.dart';
import 'svg.dart';

/// A generic HMB button with optional hint shown on long press.
class HMBButton extends StatelessWidget {
  final String label;
  final Icon? icon;
  final VoidCallback onPressed;
  final bool enabled;
  final Color color;
  final String hint;
  final bool _smallFlag;

  const HMBButton({
    required this.label,
    required this.onPressed,
    required this.hint,
    this.enabled = true,
    super.key,
    this.color = HMBColors.buttonLabel,
  }) : icon = null,
       _smallFlag = false;

  const HMBButton.withIcon({
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.hint,
    this.enabled = true,
    this.color = HMBColors.buttonLabel,
    super.key,
  }) : _smallFlag = false;

  /// Small variant (compact height/padding/font).
  const HMBButton.small({
    required this.label,
    required this.onPressed,
    required this.hint,
    this.enabled = true,
    this.color = HMBColors.buttonLabel,
    super.key,
  }) : icon = null,
       _smallFlag = true;

  /// Small variant with leading icon.
  const HMBButton.smallWithIcon({
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.hint,
    this.enabled = true,
    this.color = HMBColors.buttonLabel,
    super.key,
  }) : _smallFlag = true;

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? ElevatedButton.icon(
            onPressed: enabled ? onPressed : null,
            label: Text(label, style: TextStyle(color: color)),
            icon: icon,
            style: _smallFlag ? _smallStyle(context) : null,
          )
        : ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: _smallFlag ? _smallStyle(context) : null,
            child: Text(label, style: TextStyle(color: color)),
          );

    return HMBTooltip(hint: hint, child: button);
  }

  ButtonStyle _smallStyle(BuildContext context) => ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    minimumSize: const Size(0, 28),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: color,
    ),
  );
}

/// A primary-styled button with optional SVG icon and hint on long press.
class HMBButtonPrimary extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  final String? svg;

  final Color? svgColor;

  final bool enabled;
  final String hint;

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

    return HMBTooltip(hint: hint, child: btn);
  }
}

/// A secondary-styled button with hint on long press.
class HMBButtonSecondary extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final String hint;

  const HMBButtonSecondary({
    required this.label,
    required this.onPressed,
    required this.hint,
    super.key,
  });

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

    return HMBTooltip(hint: hint, child: btn);
  }
}

/// A link-style button that launches a URL and shows a hint on long press.
class HMBLinkButton extends StatelessWidget {
  final String label;
  final String link;
  final String hint;

  const HMBLinkButton({
    required this.label,
    required this.link,
    required this.hint,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final btn = TextButton(
      onPressed: () => unawaited(_launchURL(link)),
      child: Text(label, style: const TextStyle(color: Colors.blue)),
    );

    return HMBTooltip(hint: hint, child: btn);
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri);
  }
}
