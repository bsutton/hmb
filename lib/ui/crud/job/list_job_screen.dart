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

import '../../../dao/dao_job.dart';
import '../../../entity/job.dart';
import '../../../entity/job_status_stage.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/select/select.g.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../../widgets/widgets.g.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'copy_job.dart';
import 'edit_job_screen.dart';
import 'list_job_card.dart';

class JobListScreen extends StatefulWidget {
  static const pageTitle = 'Jobs';

  const JobListScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _JobListScreenState createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  var _showOldJobs = false;
  var _order = JobOrder.active;

  List<Widget> _buildActionItems(Job job) => [
    IconButton(
      tooltip: 'Copy job & move tasks',
      icon: const Icon(Icons.copy),
      onPressed: () => _onCopyAndMovePressed(job),
    ),
  ];

  final _entityListKey = GlobalKey<EntityListScreenState<Job>>();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Surface(
      elevation: SurfaceElevation.e0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: EntityListScreen<Job>(
              key: _entityListKey,
              dao: DaoJob(),
              pageTitle: JobListScreen.pageTitle,
              onEdit: (job) => JobEditScreen(job: job),
              fetchList: _fetchJobs,
              title: (job) => HMBCardTitle(job.summary),
              cardHeight: size.width < 456 ? 840 : 750,
              filterSheetBuilder: _buildFilterSheet,
              isFilterActive: () => _showOldJobs || _order != JobOrder.active,
              onFilterReset: () {
                _showOldJobs = false;
                _order = JobOrder.active;
              },
              background: (job) async => job.status.getColour(),
              details: (job) =>
                  ListJobCard(job: job, key: ValueKey(job.hashCode)),
              buildActionItems: _buildActionItems,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Job>> _fetchJobs(String? filter) async {
    final jobs = await DaoJob().getByFilter(filter, order: _order);
    final selected = <Job>[];
    for (final job in jobs) {
      final stage = job.status.stage;
      if (_showOldJobs) {
        if (stage == JobStatusStage.onHold ||
            stage == JobStatusStage.finalised) {
          selected.add(job);
        }
      } else {
        if (stage == JobStatusStage.preStart ||
            stage == JobStatusStage.progressing) {
          selected.add(job);
        }
      }
    }
    return selected;
  }

  Widget _buildFilterSheet(void Function() onChange) => Column(
    children: [
      HMBDroplist<JobOrder>(
        title: 'Sort Order',
        selectedItem: () async => _order,
        items: (_) async => JobOrder.values,
        format: (order) => order.description,
        onChanged: (order) {
          _order = order!;
          onChange();
        },
      ),
      const HMBSpacer(height: true),
      SwitchListTile(
        title: const Text('Show only Old Jobs'),
        value: _showOldJobs,
        onChanged: (val) {
          setState(() {
            _showOldJobs = val;
          });
          onChange();
        },
      ).help(
        'Show only Old Jobs',
        'Only show Jobs that are on hold or have been finalised.',
      ),
    ],
  );

  Future<void> _onCopyAndMovePressed(Job job) async {
    final result = await selectTasksToMoveAndDescribeJob(
      context: context,
      job: job,
    );
    if (result == null) {
      return;
    }

    try {
      final newJob = await DaoJob().copyJobAndMoveTasks(
        job: job,
        tasksToMove: result.selectedTasks,
        summary: result.summary, // <-- pass new description
        // newJobStatus: JobStatus.prospecting, // optional override
      );

      HMBToast.info(
        '''Created Job #${newJob.id} and moved ${result.selectedTasks.length} task(s).''',
      );

      await _entityListKey.currentState!.refresh();
      // June.getState(
      //   JobRefresher.new,
      // ).setState(); // if your refresher supports it
    } catch (e) {
      HMBToast.error(e.toString());
    }
  }
}

// class FilterState extends JuneState {
//   var _showOnHoldAndFinalised = false;

//   void toggle() {
//     _showOnHoldAndFinalised = !_showOnHoldAndFinalised;
//     setState();
//   }
// }
