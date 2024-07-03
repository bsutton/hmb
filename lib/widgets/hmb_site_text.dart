import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../dao/dao_site.dart';
import '../entity/job.dart';
import '../entity/site.dart';
import 'hmb_map_icon.dart';

class HMBSiteText extends StatelessWidget {
  const HMBSiteText({required this.label, required this.site, super.key});
  final String label;
  final Site? site;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (site != null && Strings.isNotEmpty(label)) Text(label),
          Text(Strings.join([
            site?.addressLine1,
            site?.addressLine2,
            site?.suburb,
            site?.state,
            site?.postcode
          ], separator: ', ', excludeEmpty: true)),
          if (site != null)
            if (site != null) HMBMapIcon(site),
        ],
      );
}

class HMBJobSiteText extends StatelessWidget {
  const HMBJobSiteText({required this.label, required this.job, super.key});
  final String label;
  final Job? job;

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
      // ignore: discarded_futures
      future: DaoSite().getByJob(job),
      builder: (context, site) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (site != null && Strings.isNotEmpty(label)) Text(label),
              Text(Strings.join([
                site?.addressLine1,
                site?.addressLine2,
                site?.suburb,
                site?.state,
                site?.postcode
              ], separator: ', ', excludeEmpty: true)),
              if (site != null) HMBMapIcon(site),
            ],
          ));
}
