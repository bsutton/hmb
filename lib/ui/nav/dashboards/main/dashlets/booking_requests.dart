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
import 'package:go_router/go_router.dart';

import '../../../../../api/ihserver/booking_request_sync_service.dart';
import '../../../../../dao/dao_booking_request.dart';
import '../../../../widgets/hmb_toast.dart';
import '../../dashlet_card.dart';

class BookingRequestsDashlet extends StatelessWidget {
  const BookingRequestsDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<int>.onTap(
    label: 'New Requests',
    hint: 'Website booking requests awaiting review',
    icon: Icons.notification_important,
    value: () async {
      final count = await DaoBookingRequest().countPending();
      return DashletValue<int>(
        count,
        count > 0 ? 'Tap to review' : 'All caught up',
      );
    },
    onTap: (ctx) async {
      final existingCount = await DaoBookingRequest().countPending();
      var syncFailed = false;
      try {
        await BookingRequestSyncService().sync(force: true);
      } catch (_) {
        syncFailed = true;
      }
      if (!ctx.mounted) {
        return;
      }
      if (syncFailed && existingCount == 0) {
        HMBToast.error(
          'Unable to reach the booking server. Is ihserver running?',
        );
      }
      GoRouter.of(ctx).go('/home/booking_requests');
    },
  );
}
