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

import '../../../../../entity/entity.g.dart';
import '../../../../widgets/layout/layout.g.dart';
import '../../dashlet_card.dart';

class TodayDashlet extends StatelessWidget {
  const TodayDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<JobActivity?>.route(
    label: 'Today',
    hint: 'A summary of Todays activities',
    icon: Icons.assignment,
    // ignore: discarded_futures
    value: () async => const DashletValue<JobActivity>.empty(),
    valueBuilder: (ctx, dv) => const HMBEmpty(),
    route: '/home/today',
  );
}
