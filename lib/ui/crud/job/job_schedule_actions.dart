import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/format.dart';
import '../../scheduling/schedule_page.dart';
import '../../widgets/widgets.g.dart';

/// Direct scheduling actions shared by the job summary's status area.
class JobScheduleActions extends StatefulWidget {
  final Job job;
  final Future<void> Function()? onChanged;

  const JobScheduleActions({required this.job, this.onChanged, super.key});

  @override
  State<JobScheduleActions> createState() => _JobScheduleActionsState();
}

class _JobScheduleActionsState extends DeferredState<JobScheduleActions> {
  JobActivity? _next;

  @override
  Future<void> asyncInitState() => _load();

  Future<void> _load() async {
    final activities = await DaoJobActivity().getByJob(widget.job.id);
    final now = DateTime.now();
    final upcoming =
        activities.where((activity) => activity.start.isAfter(now)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    _next = upcoming.firstOrNull;
  }

  Future<void> _open({required bool next}) async {
    final system = await BlockingUI().runAndWait(DaoSystem().get);
    if (!mounted) {
      return;
    }
    if (system.getOperatingHours().noOpenDays()) {
      HMBToast.error('Set your opening hours in Settings | Business first.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SchedulePage(
          dialogMode: true,
          defaultView: ScheduleView.week,
          defaultJob: widget.job.id,
          initialActivityId: next ? _next?.id : null,
        ),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) {
      return;
    }
    await BlockingUI().runAndWait(_load);
    if (mounted) {
      setState(() {});
      await widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    waitingBuilder: (_) => const SizedBox.shrink(),
    errorBuilder: (_, error) => const Text('Could not load visits.'),
    builder: (_) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        HMBButtonSecondary(
          quiet: true,
          label: 'Schedule',
          hint: 'Schedule a visit for this job',
          onPressed: () => _open(next: false),
        ),
        HMBButtonSecondary(
          quiet: true,
          label: _next == null
              ? 'Next: none'
              : 'Next: ${formatDateTimeAM(_next!.start)}',
          hint: 'Open the next scheduled visit',
          onPressed: _next == null ? null : () => _open(next: true),
        ),
      ],
    ),
  );
}
