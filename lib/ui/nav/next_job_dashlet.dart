import 'package:flutter/material.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/util.g.dart';
import '../scheduling/schedule_page.dart';
import 'nav.g.dart';

class NextJobDashlet extends StatelessWidget {
  const NextJobDashlet({super.key});

  @override
  Widget build(BuildContext context) => DashletCard<JobActivity?>(
    label: 'Next Job',
    icon: Icons.schedule,
    // ignore: discarded_futures
    dashletValue: getNextJob,
    widgetBuilder: (ctx, dv) {
      if (dv.value == null) {
        return Text('—', style: Theme.of(ctx).textTheme.titleSmall);
      }
      final date = formatDate(dv.value!.start.toLocal(), format: 'D h:i');
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(date, style: Theme.of(ctx).textTheme.titleSmall),
          if (dv.secondValue != null)
            Text(
              dv.secondValue!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
        ],
      );
    },
    builder: (_, dv) => SchedulePage(
      defaultView: ScheduleView.week,
      initialActivityId: dv.value?.id,
      dialogMode: true,
    ),
  );

  Future<DashletValue<JobActivity?>> getNextJob() async {
    final acts = await DaoJobActivity().getActivitiesInRange(
      LocalDate.today(),
      LocalDate.today().addDays(7),
    );
    final act = acts.isEmpty ? null : acts.first;
    return DashletValue(act, act?.notes);
  }
}
