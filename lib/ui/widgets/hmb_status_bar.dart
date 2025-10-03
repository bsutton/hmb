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
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_job.dart';
import '../../entity/task.dart';
import '../../entity/time_entry.dart';
import 'hmb_start_time_entry.dart';
import 'layout/layout.g.dart';

class HMBStatusBar extends StatelessWidget {
  final TimeEntry? activeTimeEntry;
  final Task? task;
  final VoidCallback onTimeEntryEnded;

  const HMBStatusBar({
    required this.activeTimeEntry,
    required this.task,
    required this.onTimeEntryEnded,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (activeTimeEntry == null) {
      return Container();
    }
    return ColoredBox(
      color: Colors.purpleAccent,
      child: HMBRow(
        children: [
          HMBStartTimeEntry(task: task, onStart: (_, _) => {}),
          Expanded(
            child: FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoJob().getJobForTask(task?.id),
              builder: (context, job) => Text(
                '${task!.name} - ${job!.summary}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
