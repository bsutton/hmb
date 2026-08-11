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

import '../../../entity/job.dart';
import '../../../entity/site.dart';
import '../../../integrations/google_calendar/google_calendar_sync.dart';
import '../../../util/dart/address_format.dart';
import '../../../util/flutter/clip_board.dart';
import '../../../util/flutter/google_maps.dart';
import '../hmb_toast.dart';

class HMBMapIcon extends StatelessWidget {
  final Site? site;
  final Job? job;

  final Future<void> Function()? onMapClicked;

  const HMBMapIcon(this.site, {this.job, super.key, this.onMapClicked});

  @override
  Widget build(BuildContext context) {
    final address = joinAddressParts([
      site?.addressLine1,
      site?.addressLine2,
      site?.suburb,
      site?.state,
      site?.postcode,
    ]);
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
          onPressed: () {
            if (site != null) {
              unawaited(_openMap(context, site!));
            }
          },
          color: site != null && !site!.isEmpty() ? Colors.blue : Colors.grey,
          tooltip: 'Get Directions',
        ),
        IconButton(
          iconSize: 22,
          icon: const Icon(Icons.copy),
          onPressed: () {
            if (Strings.isNotEmpty(address)) {
              unawaited(clipboardCopyTo(address));
              final callback = onMapClicked;
              if (callback != null) {
                unawaited(callback());
              }
            }
          },
          color: Strings.isEmpty(address) ? Colors.grey : Colors.blue,
          tooltip: 'Copy Address to the Clipboard',
        ),
      ],
    );
  }

  Future<void> _openMap(BuildContext context, Site site) async {
    await GoogleMaps.openMap(context, site);
    final callback = onMapClicked;
    if (callback != null) {
      await callback();
    }
    final selectedJob = job;
    if (selectedJob == null) {
      return;
    }
    try {
      final result = await GoogleCalendarSyncService().recordNavigation(
        job: selectedJob,
        site: site,
      );
      if (result == ExternalCalendarSyncResult.unavailable) {
        HMBToast.info(
          'Directions opened, but Google Calendar is not signed in.',
        );
      }
    } catch (error) {
      HMBToast.error(
        'Directions opened, but the safety calendar event failed: $error',
      );
    }
  }
}
