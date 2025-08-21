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

// lib/src/ui/dashboard/help_dashlet.dart
import 'package:flutter/material.dart';

import '../../../../../src/appname.dart';
import '../../dashlet_card.dart';

/// Dashlet for Help sub-dashboard
class HelpDashlet extends StatelessWidget {
  const HelpDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>.route(
    label: 'Help',
    hint: 'Learn about and get support for $appName',
    icon: Icons.help,
    value: () => Future.value(const DashletValue(null)),
    route: '/home/help',
    valueBuilder: (_, _) => const SizedBox.shrink(),
  );
}
