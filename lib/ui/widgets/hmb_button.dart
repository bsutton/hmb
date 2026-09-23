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

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../util/flutter/hmb_theme.dart';
import 'hmb_tooltip.dart';
import 'icons/svg.dart';

/// A generic HMB button with optional hint shown on long press.
class HMBButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final VoidCallback onPressed;
  final bool enabled;
  final Color color;
  final String hint;
  final bool showTooltip;
  final bool _smallFlag;

  const HMBButton({
    required this.label,
    required this.onPressed,
    required this.hint,
    this.enabled = true,
    this.showTooltip = true,
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
    this.showTooltip = true,
    super.key,
  }) : _smallFlag = false;

  /// Small variant (compact height/padding/font).
  const HMBButton.small({
    required this.label,
    required this.onPressed,
    required this.hint,
    this.enabled = true,
    this.color = HMBColors.buttonLabel,
    this.showTooltip = true,
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
    this.showTooltip = true,
    super.key,
  }) : _smallFlag = true;

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? ElevatedButton.icon(
            onPressed: enabled ? onPressed : null,
            label: Text(label, style: TextStyle(color: enabled ? color : null)),
            icon: IconTheme.merge(
              data: IconThemeData(
                color: enabled ? color : null,
                size: _smallFlag ? 18 : 24,
              ),
              child: icon!,
            ),
            style: _smallFlag ? _smallStyle(context) : null,
          )
        : ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: _smallFlag ? _smallStyle(context) : null,
            child: Text(label, style: TextStyle(color: enabled ? color : null)),
          );

    return showTooltip ? HMBTooltip(hint: hint, child: button) : button;
  }

  ButtonStyle _smallStyle(BuildContext context) => ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    minimumSize: const Size(0, 32),
    tapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
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
    final callback = enabled ? onPressed : null;
    final btn = svg == null
        ? ElevatedButton(onPressed: callback, child: Text(label))
        : ElevatedButton.icon(
            onPressed: callback,
            label: Text(label),
            icon: Builder(
              builder: (context) => Svg(
                svg!,
                height: 24,
                width: 24,
                color: callback == null
                    ? IconTheme.of(context).color
                    : svgColor ?? IconTheme.of(context).color,
              ),
            ),
          );

    return HMBTooltip(hint: hint, child: btn);
  }
}

/// A secondary-styled button with hint on long press.
class HMBButtonSecondary extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final String hint;
  final bool quiet;

  const HMBButtonSecondary({
    required this.label,
    required this.onPressed,
    required this.hint,
    this.quiet = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Secondary actions need a visible boundary on touch screens too.
    final btn = OutlinedButton(
      onPressed: onPressed,
      style:
          OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            visualDensity: VisualDensity.standard,
            backgroundColor: quiet ? scheme.surfaceContainerLow : null,
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? scheme.onSurface.withValues(alpha: 0.12)
                    : quiet
                    ? scheme.outline
                    : scheme.primary,
              ),
            ),
          ),
      child: Text(label),
    );

    return HMBTooltip(hint: hint, child: btn);
  }
}

/// The standard outlined cancellation action for screens and dialogs.
class HMBCancelButton extends HMBButtonSecondary {
  const HMBCancelButton({
    required VoidCallback? onPressed,
    bool enabled = true,
    super.hint = 'Discard changes',
    super.label = 'Cancel',
    super.key,
    super.quiet = false,
  }) : super(onPressed: enabled ? onPressed : null);
}

/// Consistent touch-friendly actions for editing screens and dialogs.
class HMBSaveCancelButtons extends StatelessWidget {
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final bool saveEnabled;
  final String saveLabel;
  final String saveHint;
  final String cancelHint;

  const HMBSaveCancelButtons({
    required this.onSave,
    required this.onCancel,
    this.saveEnabled = true,
    this.saveLabel = 'Save',
    this.saveHint = 'Save your changes',
    this.cancelHint = 'Discard changes',
    super.key,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      SizedBox(
        height: 48,
        child: HMBButtonPrimary(
          label: saveLabel,
          hint: saveHint,
          enabled: saveEnabled,
          onPressed: onSave,
        ),
      ),
      HMBCancelButton(hint: cancelHint, onPressed: onCancel),
    ],
  );
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
      child: Text(label),
    );

    return HMBTooltip(hint: hint, child: btn);
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri);
  }
}

/// A shared underlined action beneath a selection field.
class HMBActionLink extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const HMBActionLink({
    required this.label,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    child: Text(
      label,
      style: const TextStyle(decoration: TextDecoration.underline),
    ),
  );
}
