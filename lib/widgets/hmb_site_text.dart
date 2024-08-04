import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../dao/dao_site.dart';
import '../entity/job.dart';
import '../entity/site.dart';
import 'hmb_map_icon.dart';
import 'hmb_placeholder.dart';

class HMBSiteText extends StatelessWidget {
  const HMBSiteText({required this.label, required this.site, super.key});
  final String label;
  final Site? site;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          if (site != null && Strings.isNotEmpty(label))
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          Expanded(
            child: Text(
              Strings.join([
                site?.addressLine1,
                site?.addressLine2,
                site?.suburb,
                site?.state,
                site?.postcode
              ], separator: ', ', excludeEmpty: true),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (site != null) HMBMapIcon(site)
        ],
      );
}

class HMBJobSiteText extends StatelessWidget {
  const HMBJobSiteText({required this.label, required this.job, super.key});
  final String label;
  final Job? job;

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
      waitingBuilder: (_) => const HMBPlaceHolder(height: 32),
      // ignore: discarded_futures
      future: DaoSite().getByJob(job),
      builder: (context, site) => HMBSiteText(
            label: label,
            site: site,
          ));
}
