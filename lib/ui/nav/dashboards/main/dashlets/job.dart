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

/// Dashlet for active jobs count
library;

import 'package:flutter/material.dart';

import '../../../../../dao/dao.g.dart';
import '../../../../../entity/entity.g.dart';
import '../../dashlet_card.dart';

class JobsDashlet extends StatelessWidget {
  const JobsDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<String>.route(
    label: 'Jobs',
    hint:
        'Create, Estimate, Quote, Track and Invoice Jobs.\n'
        'Value format is billable/non-billable active jobs.',
    icon: Icons.work,
    value: () async {
      final jobs = await DaoJob().getActiveJobs(null);
      var billable = 0;
      var nonBillable = 0;
      for (final job in jobs) {
        if (job.billingType == BillingType.nonBillable) {
          nonBillable++;
        } else {
          billable++;
        }
      }
      return DashletValue('$billable/$nonBillable');
    },
    route: '/home/jobs',
  );
}
