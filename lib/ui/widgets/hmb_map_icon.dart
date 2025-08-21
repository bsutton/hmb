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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../entity/site.dart';
import '../../util/clip_board.dart';
import '../../util/google_maps.dart';

class HMBMapIcon extends StatelessWidget {
  final Site? site;

  const HMBMapIcon(this.site, {super.key});

  @override
  Widget build(BuildContext context) {
    final address = Strings.join(
      [
        site?.addressLine1,
        site?.addressLine2,
        site?.suburb,
        site?.state,
        site?.postcode,
      ],
      separator: ', ',
      excludeEmpty: true,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // added line
      mainAxisSize: MainAxisSize.min, // added
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          visualDensity: VisualDensity.compact,
          iconSize: 25,
          icon: const Icon(Icons.map),
          onPressed: () => site == null
              ? null
              : unawaited(GoogleMaps.openMap(context, site!)),
          color: site != null && !site!.isEmpty() ? Colors.blue : Colors.grey,
          tooltip: 'Get Directions',
        ),
        IconButton(
          iconSize: 22,
          icon: const Icon(Icons.copy),
          onPressed: () => Strings.isEmpty(address)
              ? null
              : unawaited(clipboardCopyTo(address)),
          color: Strings.isEmpty(address) ? Colors.grey : Colors.blue,
          tooltip: 'Copy Address to the Clipboard',
        ),
      ],
    );
  }
}
