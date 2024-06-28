import 'package:flutter/material.dart';

import '../entity/site.dart';
import '../util/google_maps.dart';

class HMBMapIcon extends StatelessWidget {
  const HMBMapIcon(this.site, {super.key});
  final Site? site;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // added line
        mainAxisSize: MainAxisSize.min, // added
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            visualDensity: VisualDensity.compact,
            iconSize: 25,
            icon: const Icon(Icons.map),
            onPressed: () async =>
                site == null ? null : GoogleMaps.openMap(context, site!),
            color: site != null && !site!.isEmpty() ? Colors.blue : Colors.grey,
            tooltip: 'Get Directions',
          ),
        ],
      );
}
