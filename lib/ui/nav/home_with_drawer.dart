import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../util/app_title.dart';
import '../widgets/hmb_start_time_entry.dart';
import '../widgets/hmb_status_bar.dart';
import 'nav_drawer.dart';

class HomeWithDrawer extends StatelessWidget {
  const HomeWithDrawer({required this.initialScreen, super.key});
  final Widget initialScreen;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.purple,
            title: JuneBuilder(
              HMBTitle.new,
              builder: (title) => Text(title.title),
            )),
        drawer: MyDrawer(),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            JuneBuilder<TimeEntryState>(
              TimeEntryState.new,
              builder: (context) {
                final state = June.getState<TimeEntryState>(TimeEntryState.new);
                if (state.activeTimeEntry != null) {
                  return HMBStatusBar(
                    activeTimeEntry: state.activeTimeEntry,
                    task: state.task,
                    onTimeEntryEnded: state.clearActiveTimeEntry,
                  );
                }
                return Container();
              },
            ),
            Flexible(child: initialScreen),
          ],
        ),
      );
}
