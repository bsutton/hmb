import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:fsm2/fsm2.dart' show StateMachine;
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';

import '../../../entity/entity.g.dart';
import '../../../fsm/job_status_fsm.dart'
    show Next, buildJobMachine, nextFromFsm;
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';
import 'edit_job_card.dart';

Future<void> showJobStatusDialog(BuildContext context, Job job) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: HMBColumn(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Job actions', style: Theme.of(context).textTheme.titleLarge),
            // The picker runs side-effects and calls back on success.
            FsmStatusPicker(
              job: job,
              onStatusChanged: () {
                Navigator.of(context).pop(); // close on success
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                HMBButton(
                  onPressed: () => Navigator.of(context).pop(),
                  label: 'Close',
                  hint: 'Close job actions',
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
  final Job job;

  /// Called after a successful transition (lets the parent close the dialog).
  final VoidCallback? onStatusChanged; // NEW

  const FsmStatusPicker({
    required this.job,
    this.onStatusChanged, // NEW
    super.key,
  });

  @override
  State<FsmStatusPicker> createState() => _FsmStatusPickerState();
}

class _FsmStatusPickerState extends DeferredState<FsmStatusPicker> {
  StateMachine? _machine;
  List<Next> _next = const [];
  var _firing = false;
  JobStatus? _lastHydratedStatus;

  var _loading = Completer<void>();
  Object? _loadError;

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
    _loadError = null;
    try {
      await BlockingUI().runAndWait(() async {
        _lastHydratedStatus = widget.job.status;
        final machine = await buildJobMachine(widget.job);
        final next = await nextFromFsm(machine: machine, job: widget.job);
        if (!mounted) {
          return;
        }
        _machine = machine;
        _next = next;
        _loading.complete();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      _machine = null;
      _next = const [];
      _loadError = e;
      _loading.complete();
      HMBToast.error('Failed to build job workflow: $e');
    }
  }

  Future<void> _moveTo(Next step) async {
    if (_machine == null || _firing) {
      return;
    }
    setState(() {
      _firing = true;
    });
    try {
      await BlockingUI().runAndWait(() => step.fire(_machine!));
      if (!mounted) {
        return;
      }
      June.getState(SelectJobStatus.new).jobStatus = widget.job.status;
      widget.onStatusChanged?.call();
    } catch (e) {
      HMBToast.error('Could not perform job action: $e');
    } finally {
      if (mounted) {
        await _hydrate();
      }
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
    waitingBuilder: (_) => const SizedBox.shrink(),
    errorBuilder: (_, error) => const Text('Could not load job actions.'),
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current status (read-only)
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: HMBRow(
            children: [
              const Text(
                'Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              HMBChip(label: widget.job.status.displayName),
            ],
          ),
        ),

        FutureBuilderEx(
          future: _loading.future,
          waitingBuilder: (_) => const SizedBox.shrink(),
          errorBuilder: (_, error) => const Text('Could not load job actions.'),
          builder: (context, _) {
            if (_loadError != null) {
              return const Text('Could not load job actions.');
            }
            if (_next.isEmpty) {
              return const Text('No actions available.');
            } else {
              return HMBColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Actions:'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _next
                        .map(
                          (n) => HMBColumn(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HMBButton(
                                enabled: !_firing,
                                onPressed: () => _moveTo(n),
                                label: n.label,
                                hint: 'Changes status to ${n.to.displayName}',
                              ),
                              Text(
                                'Status: ${n.to.displayName}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
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
