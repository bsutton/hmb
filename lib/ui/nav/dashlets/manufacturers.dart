/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/ui/dashboard/manufacturers_dashlet.dart
import 'package:flutter/material.dart';

import '../dashlet_card.dart';

/// Dashlet for Manufacturers shortcut
class ManufacturersDashlet extends StatelessWidget {
  const ManufacturersDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<void>(
    label: 'Manufacturers',
    icon: Icons.factory,
    dashletValue: () => Future.value(const DashletValue(null)),
    route: '/extras/manufacturers',
    widgetBuilder: (_, _) => const SizedBox.shrink(),
  );
}
