/// Dashlet for active jobs count
library;

import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../dashlet_card.dart';

class JobsDashlet extends StatelessWidget {
  const JobsDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>(
    label: 'Jobs',
    icon: Icons.work,
    future: DaoJob()
        .getActiveJobs(null)
        .then((jobs) => DashletValue(jobs.length)),
    route: '/jobs',
  );
}
