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
import 'package:june/june.dart';

import '../../../../../api/ihserver/booking_request_sync_service.dart';
import '../../../../../dao/dao_booking_request.dart';
import '../../dashlet_card.dart';
import '../../sync_warnings.dart';

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
    valueBuilder: (ctx, dv) => JuneBuilder(
      BookingRequestsSyncWarningState.new,
      builder: (_) {
        final warning = June.getState<BookingRequestsSyncWarningState>(
          BookingRequestsSyncWarningState.new,
        ).warning;
        if (warning == null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dv.value?.toString() ?? '',
                style: Theme.of(
                  ctx,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (dv.secondValue != null) ...[
                const SizedBox(height: 4),
                Text(
                  dv.secondValue!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ],
          );
        }
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text('Warning', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        );
      },
    ),
    onTap: (ctx) async {
      try {
        await BookingRequestSyncService().sync(force: true);
        June.getState<BookingRequestsSyncWarningState>(
          BookingRequestsSyncWarningState.new,
        ).clearWarning();
      } catch (error) {
        June.getState<BookingRequestsSyncWarningState>(
          BookingRequestsSyncWarningState.new,
        ).showWarning('Booking sync failed', formatBookingSyncWarning(error));
      }
      if (!ctx.mounted) {
        return;
      }
      GoRouter.of(ctx).go('/home/booking_requests');
    },
  );
}
