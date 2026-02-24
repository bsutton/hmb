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

// lib/src/ui/nav/home_scaffold.dart
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';

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
      backgroundColor: Colors.purple,
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
}
