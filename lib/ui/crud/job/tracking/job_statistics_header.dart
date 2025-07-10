import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart' show FutureBuilderEx;

import '../../../../dao/dao.g.dart';
import '../../../../entity/entity.g.dart';
import '../../../widgets/text/text.g.dart';
import 'list_time_entry_screen.dart';

/// Shows tasks, effort, earnings and worked‐hours for a Job.
class JobStatisticsHeader extends StatelessWidget {
  const JobStatisticsHeader({required this.job, super.key});
  final Job job;

  @override
  Widget build(BuildContext context) => FutureBuilderEx<JobStatistics>(
    waitingBuilder: (_) => const SizedBox(height: 97),
    future: DaoJob().getJobStatistics(job),
    builder: (ctx, stats) {
      if (stats == null) {
        return const CircularProgressIndicator();
      }
      final isMobile = MediaQuery.of(context).size.width < 800;
      final children = <Widget>[
        HMBText(
          'Tasks: ${stats.completedTasks}/${stats.totalTasks}',
          bold: true,
        ),
        HMBText(
          'Est. Effort: ${stats.completedLabourHours.format('0.00')}/${stats.expectedLabourHours.format('0.00')}',
          bold: true,
        ),
        HMBText(
          'Earnings: ${stats.completedMaterialCost}/${stats.totalMaterialCost}',
          bold: true,
        ),
        HMBTextClickable(
          text: 'Worked: ${stats.worked}/${stats.workedHours}hrs',
          bold: true,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => TimeEntryListScreen(job: job),
            ),
          ),
        ),
      ];

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: children,
              ),
      );
    },
  );
}
