import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../widgets.g.dart';
import 'hmb_droplist_multi.dart';

class HMBSelectJobMulti extends StatefulWidget {
  final List<Job> initialJobs;
  final void Function(List<Job>) onChanged;
  final bool allowInactiveJobs;
  final bool showInactiveJobs;
  final ValueChanged<bool>? onShowInactiveJobsChanged;

  const HMBSelectJobMulti({
    required this.initialJobs,
    required this.onChanged,
    this.allowInactiveJobs = false,
    this.showInactiveJobs = false,
    this.onShowInactiveJobsChanged,
    super.key,
  });

  @override
  State<HMBSelectJobMulti> createState() => HMBSelectJobMultiState();
}

class HMBSelectJobMultiState extends State<HMBSelectJobMulti> {
  final _droplistKey = GlobalKey<HMBDroplistMultiSelectState<CustomerAndJob>>();
  late bool _showInactiveJobs;

  bool hasSelections() => _droplistKey.currentState?.hasSelections() ?? false;

  String get _helpText {
    if (widget.allowInactiveJobs) {
      return '''
Allows you to filter the list to items from specific Jobs.

Use "Show inactive jobs" to include completed and other inactive Jobs.''';
    }
    return '''
Allows you to filter the list to items from specific Jobs.

If your Job isn't showing then update its status to an Active one such as
'Scheduled' or 'In Progress'.''';
  }

  void clear() => _droplistKey.currentState?.clear();

  @override
  void initState() {
    super.initState();
    _showInactiveJobs = widget.showInactiveJobs;
  }

  @override
  void didUpdateWidget(covariant HMBSelectJobMulti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showInactiveJobs != widget.showInactiveJobs) {
      _showInactiveJobs = widget.showInactiveJobs;
      if (!_showInactiveJobs) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _removeInactiveSelections();
          }
        });
      }
    }
  }

  void _setShowInactiveJobs(bool value) {
    setState(() {
      _showInactiveJobs = value;
    });
    if (!value) {
      _removeInactiveSelections();
    }
    widget.onShowInactiveJobsChanged?.call(value);
  }

  void _removeInactiveSelections() {
    final state = _droplistKey.currentState;
    if (state == null) {
      return;
    }
    final active = state.selectedItems.where((item) => item.isActive).toList();
    if (active.length == state.selectedItems.length) {
      return;
    }
    state.replaceSelections(active);
    widget.onChanged(active.map((item) => item.job).toList());
  }

  void _onJobsChanged(List<CustomerAndJob> selectedJobs) {
    final allowedJobs = _showInactiveJobs
        ? selectedJobs
        : selectedJobs.where((item) => item.isActive).toList();
    if (allowedJobs.length != selectedJobs.length) {
      _droplistKey.currentState?.replaceSelections(allowedJobs);
    }
    widget.onChanged(allowedJobs.map((item) => item.job).toList());
  }

  @override
  Widget build(BuildContext context) => HMBDroplistMultiSelect<CustomerAndJob>(
    key: _droplistKey,
    initialItems: () => CustomerAndJob.fromList(widget.initialJobs),
    items: (filter) =>
        CustomerAndJob.getByFilter(filter, showInactiveJobs: _showInactiveJobs),
    format: (candj) => '${candj.customer.name}\n${candj.job.summary}',
    onChanged: _onJobsChanged,
    title: 'Jobs',
    backgroundColor: SurfaceElevation.e4.color,
    required: false,
    headerBuilder: !widget.allowInactiveJobs
        ? null
        : (context, onChange) => SwitchListTile(
            title: const Text('Show inactive jobs'),
            value: _showInactiveJobs,
            onChanged: (value) {
              _setShowInactiveJobs(value);
              onChange();
            },
          ),
  ).help('Filter by Job', _helpText);
}

@immutable
class CustomerAndJob {
  final Customer customer;
  final Job job;

  const CustomerAndJob._internal(this.customer, this.job);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CustomerAndJob &&
        other.customer.id == customer.id &&
        other.job.id == job.id;
  }

  @override
  int get hashCode => Object.hash(customer.id, job.id);

  bool get isActive =>
      job.status != JobStatus.rejected &&
      job.status != JobStatus.onHold &&
      job.status != JobStatus.awaitingPayment &&
      job.status != JobStatus.completed &&
      job.status != JobStatus.toBeBilled;

  static Future<List<CustomerAndJob>> fromList(List<Job> jobs) async {
    final list = <CustomerAndJob>[];

    final daoCustomer = DaoCustomer();
    for (final job in jobs) {
      final customer = await daoCustomer.getByJob(job.id);
      list.add(CustomerAndJob._internal(customer!, job));
    }
    return list;
  }

  static Future<List<CustomerAndJob>> getByFilter(
    String? filter, {
    required bool showInactiveJobs,
  }) async {
    final jobs = showInactiveJobs
        ? await DaoJob().getByFilter(filter)
        : await DaoJob().getActiveJobs(filter);

    final list = <CustomerAndJob>[];

    final daoCustomer = DaoCustomer();
    for (final job in jobs) {
      final customer = await daoCustomer.getByJob(job.id);
      list.add(CustomerAndJob._internal(customer!, job));
    }
    return list;
  }
}
