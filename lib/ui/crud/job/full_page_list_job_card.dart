import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../dao/dao_job.dart';
import '../../../entity/job.dart';
import '../../widgets/blocking_ui.dart';
import '../../widgets/layout/layout.g.dart';
import 'job_activity_timeline_section.dart';
import 'list_job_card.dart';

class FullPageListJobCard extends StatefulWidget {
  final Job job;

  const FullPageListJobCard(this.job, {super.key});

  @override
  State<FullPageListJobCard> createState() => _FullPageListJobCardState();
}

class _FullPageListJobCardState extends DeferredState<FullPageListJobCard> {
  @override
  Future<void> asyncInitState() async {
    // Viewing a job records recency without starting work on it.
    await BlockingUI().runAndWait(() => DaoJob().markLastActive(widget.job.id));
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Job',
    child: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, error) => const Text('Could not load job details.'),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListJobCard(job: widget.job),
            const HMBSpacer(height: true),
            JobActivityTimelineSection(job: widget.job),
          ],
        ),
      ),
    ),
  );
}
