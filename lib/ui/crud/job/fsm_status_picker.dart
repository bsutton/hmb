import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/widgets.dart';
import 'package:fsm2/fsm2.dart' show StateMachine;
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';

import '../../../entity/entity.g.dart';
import '../../../fsm/job_status_fsm.dart'
    show Next, buildJobMachine, nextFromFsm;
import '../../widgets/hmb_chip.dart';
import '../../widgets/widgets.g.dart';
import 'edit_job_card.dart';

class FsmStatusPicker extends StatefulWidget {
  const FsmStatusPicker({required this.job, super.key});
  final Job job;

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
    setState(() {
      _loading = Completer<void>();
    });
    try {
      _lastHydratedStatus = widget.job.status;
      final machine = await buildJobMachine(widget.job);
      final next = await nextFromFsm(machine: machine, job: widget.job);
      if (!mounted) {
        return;
      }
      setState(() {
        _machine = machine;
        _next = next;
        _loading.complete();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _next = const [];
        _loading.complete();
      });
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
      June.getState(SelectJobStatus.new).jobStatus = widget.job.status;
      HMBToast.info('Status updated to ${widget.job.status.displayName}');
    } catch (e) {
      HMBToast.error('Could not change status: $e');
    } finally {
      await _hydrate(); // recompute next steps from the new state
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
                            enabled: _firing,
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
