// lib/src/ui/nav/home_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';

import '../../util/app_title.dart';
import '../widgets/hmb_start_time_entry.dart';
import '../widgets/hmb_status_bar.dart';

/// A scaffold that wraps all screens and adds:
///  • a Home button in the AppBar
///  • the HMB status bar
class HomeScaffold extends StatelessWidget {
  const HomeScaffold({required this.initialScreen, super.key});
  final Widget initialScreen;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.purple,
      // ▶️ Home button replaces the old drawer
      leading: IconButton(
        icon: const Icon(Icons.home),
        onPressed: () => GoRouter.of(context).go('/dashboard'),
      ),
      title: JuneBuilder(HMBTitle.new, builder: (title) => Text(title.title)),
    ),
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show active time entry bar when appropriate
        JuneBuilder<TimeEntryState>(
          TimeEntryState.new,
          builder: (_) {
            final state = June.getState<TimeEntryState>(TimeEntryState.new);
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
