import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../dao/dao_job.dart';
import '../entity/task.dart';
import '../entity/time_entry.dart';
import 'hmb_start_time_entry.dart';

class HMBStatusBar extends StatelessWidget {
  const HMBStatusBar({
    required this.activeTimeEntry,
    required this.task,
    required this.onTimeEntryEnded,
    super.key,
  });

  final TimeEntry? activeTimeEntry;
  final Task? task;
  final VoidCallback onTimeEntryEnded;

  @override
  Widget build(BuildContext context) {
    if (activeTimeEntry == null) {
      return Container();
    }
    return Container(
      color: Colors.blueAccent,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          HMBStartTimeEntry(task: task),
          const SizedBox(width: 8),
          Expanded(
            child: FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoJob().getJobForTask(task!),
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
