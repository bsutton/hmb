import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:fsm2/fsm2.dart' show StateMachine;
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../entity/entity.g.dart';
import '../../../fsm/job_status_fsm.dart'
    show Next, buildJobMachine, nextFromFsm;
import '../../widgets/widgets.g.dart';
import 'edit_job_card.dart';

Future<void> showJobStatusDialog(BuildContext context, Job job) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update Job Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            // The picker runs side-effects and calls back on success.
            FsmStatusPicker(
              job: job,
              onStatusChanged: () {
                Navigator.of(context).pop(); // close on success
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class FsmStatusPicker extends StatefulWidget {
  const FsmStatusPicker({
    required this.job,
    this.onStatusChanged, // NEW
    super.key,
  });

  final Job job;

  /// Called after a successful transition (lets the parent close the dialog).
  final VoidCallback? onStatusChanged; // NEW

  @override
  State<FsmStatusPicker> createState() => _FsmStatusPickerState();
}

class _FsmStatusPickerState extends DeferredState<FsmStatusPicker> {
  StateMachine? _machine;
  List<Next> _next = const [];
  var _firing = false;
  JobStatus? _lastHydratedStatus;

  var _loading = Completer<void>();

  @override
  Future<void> asyncInitState() async {
    await _hydrate();
  }

  @override
  void didUpdateWidget(covariant FsmStatusPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild the FSM if the job or its status changed.
    if (oldWidget.job.id != widget.job.id ||
        _lastHydratedStatus != widget.job.status) {
      unawaited(_hydrate());
    }
  }

  Future<void> _hydrate() async {
    _loading = Completer<void>();
    try {
      _lastHydratedStatus = widget.job.status;
      final machine = await buildJobMachine(widget.job);
      final next = await nextFromFsm(machine: machine, job: widget.job);
      if (!mounted) {
        return;
      }
      _machine = machine;
      _next = next;
      _loading.complete();
    } catch (e) {
      if (!mounted) {
        return;
      }
      _next = const [];
      _loading.complete();
      HMBToast.error('Failed to build job workflow: $e');
    }
  }

  Future<void> _moveTo(Next step) async {
    if (_machine == null) {
      return;
    }
    setState(() {
      _firing = true;
    });
    try {
      await step.fire(_machine!); // runs side-effects & persists
      // Keep the UI model in sync with the new status.
      widget.job.status = step.to;
      June.getState(SelectJobStatus.new).jobStatus = step.to;

      widget.onStatusChanged?.call(); // NEW: tell parent we succeeded
    } catch (e) {
      HMBToast.error('Could not change status: $e');
    } finally {
      await _hydrate();
      if (mounted) {
        setState(() {
          _firing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current status (read-only)
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              const Text(
                'Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              HMBChip(label: widget.job.status.displayName),
            ],
          ),
        ),

        FutureBuilderEx(
          future: _loading.future,
          builder: (context, _) {
            if (_next.isEmpty) {
              return const Text('No valid next steps.');
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Move to:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _next
                        .map(
                          (n) => HMBButton(
                            enabled: !_firing,
                            onPressed: () => _moveTo(n),
                            label: n.to.displayName,
                            hint: '',
                          ),
                        )
                        .toList(),
                  ),
                ],
              );
            }
          },
        ),
      ],
    ),
  );
}
