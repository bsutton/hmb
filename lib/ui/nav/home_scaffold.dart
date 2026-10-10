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

import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';
// lib/src/ui/nav/home_scaffold.dart
import 'package:material_ui/material_ui.dart';

import '../../api/trip_capture_service.dart';
import '../../dao/dao_job.dart';
import '../../util/flutter/app_title.dart';
import '../widgets/hmb_start_time_entry.dart';
import '../widgets/hmb_status_bar.dart';
import '../widgets/layout/layout.g.dart';

/// A scaffold that wraps all screens and adds:
///  • a Home button in the AppBar
///  • the HMB status bar
class HomeScaffold extends StatelessWidget {
  final Widget initialScreen;

  const HomeScaffold({required this.initialScreen, super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      // ▶️ Home button replaces the old drawer
      leading: IconButton(
        icon: const Icon(Icons.home),
        onPressed: () => GoRouter.of(context).go('/home'),
      ),
      title: JuneBuilder(
        HMBTitle.new,
        builder: (title) => FutureBuilderEx(
          future: DaoJob().getLastActiveJob(),
          builder: (context, activeJob) =>
              Text(formatAppTitle(title.title, activeJob: activeJob)),
        ),
      ),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: TripCaptureService.instance.isGpsTracking,
          builder: (context, tracking, _) => tracking
              ? IconButton(
                  icon: const Icon(Icons.gps_fixed),
                  tooltip: 'GPS trip tracking active. Tap to stop.',
                  onPressed: () => _confirmStopGpsTracking(context),
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
    body: HMBColumn(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show active time entry bar when appropriate
        JuneBuilder<ActiveTimeEntryState>(
          ActiveTimeEntryState.new,
          builder: (_) {
            final state = June.getState<ActiveTimeEntryState>(
              ActiveTimeEntryState.new,
            );
            if (state.activeTimeEntry != null) {
              return HMBStatusBar(
                activeTimeEntry: state.activeTimeEntry,
                task: state.task,
                onTimeEntryEnded: state.clearActiveTimeEntry,
              );
            }
            return const SizedBox.shrink();
          },
        ),
        Flexible(child: initialScreen),
      ],
    ),
  );

  Future<void> _confirmStopGpsTracking(BuildContext context) async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop GPS tracking?'),
        content: const Text(
          'The current GPS trip will be saved and background tracking '
          'will stop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep tracking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop tracking'),
          ),
        ],
      ),
    );
    if (stop ?? false) {
      await TripCaptureService.instance.stopGpsTracking();
    }
  }
}
