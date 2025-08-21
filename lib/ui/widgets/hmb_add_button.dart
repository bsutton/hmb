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

import 'package:flutter/material.dart';

import 'hmb_icon_button.dart';

/// Displays the primary site of a parent
/// and allows the user to select/update the primary site.
class HMBButtonAdd extends StatelessWidget {
  const HMBButtonAdd({
    required this.onAdd,
    required this.enabled,
    this.hint = 'Add',
    this.small = false,
    super.key,
  });
  final Future<void> Function()? onAdd;
  final bool enabled;
  final bool small;

  final String? hint;

  @override
  Widget build(BuildContext context) => HMBIconButton(
    onPressed: onAdd,
    enabled: enabled,
    size: small ? HMBIconButtonSize.small : HMBIconButtonSize.standard,
    hint: hint,
    icon: const Icon(Icons.add),
  );
}
