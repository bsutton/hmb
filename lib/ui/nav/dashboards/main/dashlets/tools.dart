/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/ui/dashboard/tools_dashlet.dart
import 'package:flutter/material.dart';

import '../../dashlet_card.dart';

/// Dashlet for Tools shortcut
class ToolsDashlet extends StatelessWidget {
  const ToolsDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>.route(
    label: 'Tools',
    hint: 'Maintain a list of tools, warranty details and receipts',
    icon: Icons.build,
    value: () => Future.value(const DashletValue(null)),
    route: '/home/tools',
    valueBuilder: (_, _) => const SizedBox.shrink(),
  );
}
