/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

/// Dashlet for active jobs count
library;

import 'package:flutter/material.dart';

import '../../../../../dao/dao.g.dart';
import '../../dashlet_card.dart';

class JobsDashlet extends StatelessWidget {
  const JobsDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>(
    label: 'Jobs',
    icon: Icons.work,
    dashletValue: () async {
      final jobs = await DaoJob().getActiveJobs(null);
      return DashletValue(jobs.length);
    },
    route: '/jobs',
  );
}
