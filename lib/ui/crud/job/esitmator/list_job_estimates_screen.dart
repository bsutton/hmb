/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../../../dao/dao.g.dart';
import '../../../../entity/entity.g.dart';
import '../../../../util/app_title.dart';
import '../../../widgets/layout/hmb_spacer.dart';
import '../../../widgets/text/text.g.dart';
import '../../base_full_screen/base_full_screen.g.dart';
import 'job_card.dart';

class JobEstimatesListScreen extends StatefulWidget {
  const JobEstimatesListScreen({super.key, this.job});

  final Job? job;

  @override
  State<JobEstimatesListScreen> createState() => _JobEstimatesListScreenState();
}

class _JobEstimatesListScreenState extends State<JobEstimatesListScreen> {
  var _onlyShowQutableJobs = true;

  @override
  void initState() {
    super.initState();
    setAppTitle('Estimator');
  }

  Future<List<Job>> _fetchFiltered(String? filter) async {
    List<Job> rawJobs;
    if (_onlyShowQutableJobs) {
      rawJobs = await DaoJob().getQuotableJobs(filter);
    } else {
      rawJobs = await DaoJob().getByFilter(filter);
    }

    final jobList = <Job>[];
    for (final job in rawJobs) {
      final customer = await DaoCustomer().getByJob(job.id);
      if (customer == null) {
        continue;
      }

      // final contact = await DaoContact().getPrimaryForJob(job.id);

      // final hasBillables =
      //     await DaoJob().hasBillableTasks(job) ||
      //     await DaoJob().hasBillableBookingFee(job);
      // if (_onlyBillables && !hasBillables) {
      //   continue;
      // }

      // final cj = CustomerAndJob(
      //   customer: customer,
      //   job: job,
      //   hasBillables: hasBillables,
      //   contactName: contact?.fullname,
      // );
      jobList.add(job);
    }

    return jobList;
  }

  @override
  Widget build(BuildContext context) => EntityListScreen<Job>(
    pageTitle: 'Estimator',
    dao: DaoJob(), // dummy DAO just to meet API, not used
    fetchList: _fetchFiltered,
    showBackButton: widget.job != null,
    title: (job) async =>
        HMBTextHeadline((await _getCustomer(job))?.name ?? 'Unknown'),
    details: (job) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HMBSpacer(height: true),
        JobCard(job: job, onEstimatesUpdated: () => setState(() {})),
      ],
    ),
    cardHeight: 370,
    filterSheetBuilder: _buildFilterSheet,
    isFilterActive: () => _onlyShowQutableJobs,
    onFiltersCleared: () {
      _onlyShowQutableJobs = false;
    },
    canAdd: false,
    onEdit: (job) => JobCard(
      job: job!,
      onEstimatesUpdated: () => setState(() {}),
    ), // no edit screen
  );

  Widget _buildFilterSheet(void Function() onChange) => Column(
    children: [
      SwitchListTile(
        title: const Text('Only Show Quotable Jobs'),
        value: _onlyShowQutableJobs,
        onChanged: (val) {
          setState(() {
            _onlyShowQutableJobs = val;
          });
          onChange();
        },
      ),
    ],
  );
}

Future<Customer?> _getCustomer(Job job) async => DaoCustomer().getByJob(job.id);

class CustomerAndJob {
  CustomerAndJob({
    required this.customer,
    required this.job,
    required this.hasBillables,
    this.contactName,
  });

  final Customer customer;
  final Job job;
  final bool hasBillables;
  final String? contactName;
}
