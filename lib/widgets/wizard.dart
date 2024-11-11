import 'dart:async';

import 'package:completer_ex/completer_ex.dart';
import 'package:flutter/material.dart';

import '../util/hmb_theme.dart';
import '../util/log.dart';
import 'blocking_ui.dart';
import 'circle.dart';
import 'grayed_out.dart';
import 'hmb_button.dart';
import 'hmb_toast.dart';
import 'text/hmb_text_themes.dart';
import 'wizard_step.dart';

enum WizardCompletionReason {
  cancelled,
  completed,
  backedOut // The user clicked the hardware back button and exited the wizard.
}

typedef WizardCompletion = Future<void> Function(WizardCompletionReason reason);

/// Called each time the wizard is about to transition.
/// The transition can be tiggered via an api call or a user action. The
/// argument [userOriginated] is true if it was caused by a user action.
/// The [currentStep] is the step the wizard is currently showing
///  when the transition started.
/// The [targetStep] is the step the wizard is moving to.
typedef Transition = void Function(
    {required WizardStep currentStep,
    required WizardStep targetStep,
    required bool userOriginated});

/// Build multi-step wizards.
/// [initialSteps] the set of states the wizard starts with.
class Wizard extends StatefulWidget {
  Wizard({
    required this.initialSteps,
    super.key,
    this.onTransition,
    this.onFinished,
    this.cancelLabel = 'Cancel',
  }) : assert(initialSteps.isNotEmpty, 'Must have at least one step') {
    steps.addAll(initialSteps);
  }
  final WizardCompletion? onFinished;
  final Transition? onTransition;
  final List<WizardStep> initialSteps;
  final String cancelLabel;

  final steps = <WizardStep>[];

  @override
  State<StatefulWidget> createState() => WizardState();
}

class WizardState extends State<Wizard> {
  static const double lineInset = 7;
  static const double lineWidth = 24;

  final ScrollPhysics physics = const ClampingScrollPhysics();
  final bool _pageLoading = false;

  final bool _inTransition = false;

  late WizardStep _currentStep;

  /// Holds the index into the widget.initialSteps list of the current step.
  int _currentStepIndex = 0;

  late List<GlobalKey> _keys;

  static const Duration crossFadeDuration = Duration(milliseconds: 500);

  Future<void> popInvoked(BuildContext context) async {
    if (!isFirstVisible(_currentStepIndex)) {
      await _onBack();
    } else {
      await widget.onFinished?.call(WizardCompletionReason.backedOut);
    }
  }

  @override
  void initState() {
    super.initState();

    for (final step in widget.initialSteps) {
      step.wizardState = this;
    }

    _currentStep = widget.initialSteps[0];
    _currentStep.buildRequired = true;

    _keys = List<GlobalKey>.generate(
      widget.steps.length,
      (i) => GlobalKey(),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: isFirstVisible(_currentStepIndex),
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) {
            await popInvoked(context);
          }
        },
        child: Material(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Expanded(child: _buildBody()), _buildControls()],
          ),
        ),
      );

  Future<void> _onNext() async {
    BlockingUI().run<void>(() async {
      if (isLastVisible(_currentStepIndex)) {
        // We call nextStep to allow the page to do any 'exit' completion work.
        // We use current_step as the target as we have no actual next
        // page. The current_step is just used so we know when onNext completes.
        final WizardStep fakeLast = FakeLastStep();
        final target = WizardStepTarget(this, fakeLast);
        _currentStep.buildRequired = true;

        await _safeOnNext(context, _currentStep, target, userOriginated: true);

        final result = await target.future;
        if (result == fakeLast) {
          await widget.onFinished?.call(WizardCompletionReason.completed);
        }
        // else the onNext must have failed and redirected to itself
        // or some other page.
      } else {
        final nextStep = _nextStep(_currentStepIndex);

        if (nextStep != null) {
          await _transitionForward(nextStep, userOriginated: true);
        }
      }
    });
  }

  Future<void> _onBack() async {
    BlockingUI().run<void>(() async {
      final priorStep = _priorStep(_currentStepIndex);
      if (priorStep != null) {
        await _transitionBackwards(priorStep, userOriginated: true);
      }
    });
  }

  Future<void> _transitionForward(WizardStep targetStep,
      {required bool userOriginated}) async {
    _hideKeyboard();

    final target = WizardStepTarget(this, targetStep);
    _currentStep.buildRequired = true;
    await _safeOnNext(context, _currentStep, target,
        userOriginated: userOriginated);

    var nextStep = await target.future;

    // Check if we can transition and get the new step as
    // onNext can redirect us.
    if (nextStep != _currentStep) {
      // yes we are moving.

      // onNext decided to send us backwards so our work is now done.
      if (!isAfter(nextStep)) {
        await _transitionBackwards(nextStep, userOriginated: userOriginated);
        return;
      }

      WizardStep? tryStep;
      var firstpass = true;
      do {
        // first pass we use nextStep acquired above.
        if (firstpass) {
          firstpass = false;
        } else {
          if (!isAfter(tryStep!)) {
            await _transitionBackwards(tryStep, userOriginated: userOriginated);
            return;
          }
          nextStep = tryStep;
        }

        nextStep.buildRequired = true;
        final entryTarget = WizardStepTarget(this, nextStep);
        if (mounted) {
          await _safeOnEntry(context, nextStep, _currentStep, entryTarget,
              userOriginated: userOriginated);
        }
        tryStep = await entryTarget.future;
      } while (nextStep != tryStep);

      // onEntry is happy to let us in.
      widget.onTransition?.call(
          currentStep: _currentStep,
          targetStep: nextStep,
          userOriginated: userOriginated);

      _currentStep = nextStep;
      _currentStepIndex = _indexOf(nextStep);
      _showStep();
    } else {
      // we are not moving.
      Log.d('_transitionForward rejected by onNext');
    }
  }

  Future<void> _transitionBackwards(WizardStep targetStep,
      {required bool userOriginated}) async {
    _hideKeyboard();

    // Check if we can transition and get the new step
    // as onBack can redirect us.
    _currentStep.buildRequired = true;
    final target = WizardStepTarget(this, targetStep);
    await _safeOnPrev(context, _currentStep, target,
        userOriginated: userOriginated);

    var prevStep = await target.future;

    if (prevStep != _currentStep) {
      // yes we are moving.

      // onPrev decided to send us backwards so our work is now done.
      if (isAfter(prevStep)) {
        await _transitionForward(prevStep, userOriginated: userOriginated);
        return;
      }

      WizardStep? tryStep;
      var firstpass = true;
      // loop until onEntry returns itself rather than another
      // step that it wants to redirect us to.
      do {
        // first pass we use prevStep acquired above.
        if (firstpass) {
          firstpass = false;
        } else {
          if (isAfter(tryStep!)) {
            await _transitionForward(tryStep, userOriginated: userOriginated);
            return;
          }
          prevStep = tryStep;
        }
        prevStep.buildRequired = true;
        final entryTarget = WizardStepTarget(this, prevStep);
        if (mounted) {
          await _safeOnEntry(context, prevStep, _currentStep, entryTarget,
              userOriginated: userOriginated);
        }
        tryStep = await entryTarget.future;
      } while (prevStep != tryStep);

      // onEntry is happy to let us in.
      widget.onTransition?.call(
          currentStep: _currentStep,
          targetStep: prevStep,
          userOriginated: userOriginated);

      _currentStep = prevStep;
      _currentStepIndex = _indexOf(prevStep);
      _showStep();
    } else {
      // we are not moving.
      Log.d('_transitionBackwards rejected by onPrev');
    }
  }

  /// Allows you to force a jump to a specific step.
  /// By default we check each intermediate step to confirm that it can be
  /// skipped (by calling [jumpToStep].canSkip on each step).
  /// If one of the intermediate steps can't be skipped then the wizard
  /// will display that page calling its onEntry method.
  ///
  /// You can bypass the skip check by passing [checkCanSkip:false].
  ///
  Future<void> jumpToStep(WizardStep jumpToStep,
      {required bool userOriginated, bool checkCanSkip = true}) async {
    BlockingUI().run<void>(() async {
      if (jumpToStep.isActive &&
          jumpToStep != _currentStep &&
          !jumpToStep.hidden) {
        Log.d('wizard jump forward');
        // Is the jumpToStep after the current step?
        if (isAfter(jumpToStep)) {
          Log.d('jumpto is after');
          // we are moving forward so
          // check each intermediary step to ensure that it can be skipped.
          var targetStep = jumpToStep;
          var targetStepIndex = _currentStepIndex;
          Log.d('target_index=$targetStepIndex');

          if (checkCanSkip) {
            Log.d('skipping ${targetStep.title}');
            do {
              targetStep = _nextStep(targetStepIndex)!;
              targetStepIndex = _indexOf(targetStep);
            } while (targetStep.canSkip(context) &&
                !isLastVisible(targetStepIndex) &&
                targetStep != jumpToStep);
          }
          await _transitionForward(targetStep, userOriginated: userOriginated);
        } else {
          Log.d('wizard jump backwards');
          await _transitionBackwards(jumpToStep,
              userOriginated: userOriginated);
        }
      }
    });
  }

  void _hideKeyboard() {
    // remove the onscreen keyboard.
    FocusScope.of(context).unfocus();
  }

  void _showStep() {
    setState(() {
      // force a rebuild of the steps
    });

    // We need to scroll to the newly tapped step.
    // The delay is so the cross fade has a chance to complete.
    // This is a little hack, but there is no apparent way to hook
    // the cross fade completion so we just share a common duration.
    Future.delayed(crossFadeDuration, () async {
      await Scrollable.ensureVisible(
        _keys[_currentStepIndex].currentContext!,
        curve: Curves.fastOutSlowIn,
        duration: kThemeAnimationDuration,
      );
    });
  }

  Widget _buildBody() {
    final pages = _buildPages();
    return ListView(
      shrinkWrap: true,
      physics: physics,
      children: pages,
    );
  }

  Widget buildStepHeading(WizardStep step, int stepNo) => GrayedOut(
      grayedOut: step != _currentStep,
      child: Row(children: [buildNo(step, stepNo), step.title]));

  Widget buildNo(WizardStep step, int stepNo) => SizedBox(
      height: 60,
      child: Column(children: [
        _buildLine(!isFirstVisible(stepNo)),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Circle(
              diameter: 30,
              color: HMBColors.headingBackground,
              child: Center(
                  child: HMBTextListItem(
                (stepNo + 1).toString(),
                color: Colors.white,
              ))),
        ),
        _buildLine(!isLastVisible(stepNo))
      ]));

  Widget _buildLine(bool visible) => Container(
        width: visible ? 2.0 : 0.0,
        height: 11,
        color: Colors.grey.shade400,
      );

  Widget buildStepBody(WizardStep step) {
    if (step.buildRequired) {
      final width = MediaQuery.of(context).size.width - lineInset - lineWidth;

      // height required for phone edit return SizedBox(width: width,
      // height: 100, child: step.build(context));
      return SizedBox(width: width, child: step.build(context));
    } else {
      return const SizedBox(width: 1, height: 1);
    }
  }

  void dipose() {
    for (final step in widget.initialSteps) {
      step.dispose();
    }
  }

  List<Widget> _buildPages() {
    final children = <Widget>[];

    var stepNo = 0;
    for (var i = 0; i < widget.initialSteps.length; i += 1) {
      final step = widget.initialSteps[i];
      if (step.hidden) {
        continue;
      }
      children.add(Column(
        key: _keys[i],
        children: <Widget>[
          Material(
            child: InkWell(
              onTap: () async => jumpToStep(step, userOriginated: true),
              child: buildStepHeading(step, stepNo),
            ),
          ),
          _buildVerticalBody(step, i),
        ],
      ));
      stepNo++;
    }

    return children;
  }

  Widget _buildVerticalBody(WizardStep step, int index) => Align(
      alignment: Alignment.centerLeft,
      child: Stack(
        children: <Widget>[
          // left hand line between step circles for the body of each step.
          PositionedDirectional(
            start: lineInset,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: lineWidth,
              child: Center(
                child: SizedBox(
                  width: isLastVisible(index) ? 0.0 : 2.0,
                  child: Container(
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ),
          // The body of the step.
          // first child is a zero sized container so we expand/collapse
          // the step [secondChild] to/from the zero container.
          AnimatedCrossFade(
            firstChild: Container(height: 0),
            secondChild: Container(
              margin: const EdgeInsetsDirectional.only(
                start: 30,
              ),
              child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.centerLeft,
                  child: buildStepBody(step)),
            ),
            firstCurve: const Interval(0, 0.1, curve: Curves.fastOutSlowIn),
            secondCurve: const Interval(0, 1, curve: Curves.fastOutSlowIn),
            sizeCurve: Curves.fastOutSlowIn,
            crossFadeState: _isCurrent(index)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: crossFadeDuration,
          ),
        ],
      ));

  Widget _buildControls() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        HMBButtonSecondary(
          label: widget.cancelLabel,
          onPressed: _inTransition || _pageLoading
              // no steps back, so disable the button
              ? null
              // add handler
              : () async {
                  await widget.onFinished
                      ?.call(WizardCompletionReason.cancelled);
                },
        ),
        HMBButtonPrimary(
          label: 'Back',
          // BACK BUTTON
          onPressed:
              isFirstVisible(_currentStepIndex) || _inTransition || _pageLoading
                  // no steps back, so disable the button
                  ? null
                  // add handler
                  : _onBack,
        ),
        // NEXT BUTTON
        HMBButtonPrimary(
            label: isLastVisible(_currentStepIndex) ? 'Done' : 'Next',
            onPressed: _inTransition || _pageLoading ? null : _onNext),
      ]);

  /// Returns true if the given [index] is the index of the
  /// first step that is visible i.e. not hidden.
  bool isFirstVisible(int index) => index == _firstVisible();

  /// Returns the index of the first step that is currently visible
  int _firstVisible() {
    var index = 0;
    while (widget.steps[index].hidden) {
      index++;
    }
    return index;
  }

  /// Returns true if the given [index] is the index of the
  /// last step that is visible i.e. not hidden.
  bool isLastVisible(int index) => index == _lastVisible();

  /// Returns the index of the last step that is currently visible
  int _lastVisible() {
    var index = widget.steps.length - 1;
    while (widget.steps[index].hidden) {
      index--;
    }
    return index;
  }

  bool _isCurrent(int index) => index == _currentStepIndex;

  WizardStep? nextStep() => _nextStep(_currentStepIndex);

  /// Searches forward through the set of steps until
  /// it finds an active and visible step
  /// Returns null if no active next step exists.
  WizardStep? _nextStep(int currentStepIndex) {
    WizardStep? nextStep;
    do {
      nextStep = currentStepIndex + 1 > widget.initialSteps.length
          ? null
          : widget.initialSteps[currentStepIndex + 1];
      currentStepIndex++;
    } while (!(nextStep?.isActive ?? false) || (nextStep?.hidden ?? true));

    return nextStep;
  }

  /// Searches backward through the set of steps until
  /// it finds an active and visible step
  /// Returns null if no prior step exists.
  WizardStep? _priorStep(int currentStepIndex) {
    WizardStep? priorStep;
    do {
      priorStep = currentStepIndex - 1 < 0
          ? null
          : widget.initialSteps[currentStepIndex - 1];
      currentStepIndex--;
    } while (!(priorStep?.isActive ?? false) || (priorStep?.hidden ?? true));

    return priorStep;
  }

  WizardStep? priorStep() => _priorStep(_currentStepIndex);

  /// True if the [targetStep] is after the current step.
  bool isAfter(WizardStep targetStep) {
    final index = _indexOf(targetStep);

    return index > _currentStepIndex;
  }

  /// Throws an [ArgumentError] if the step doesn't exist.
  int _indexOf(WizardStep step) {
    for (var i = 0; i < widget.steps.length; i++) {
      if (step == widget.steps[i]) return i;
    }

    throw ArgumentError.value(step, 'Given step is not in the list of steps');
  }

  void reorderStep({required WizardStep move, required WizardStep after}) {
    setState(() {
      final removeIndex = _indexOf(move);
      widget.steps.removeAt(removeIndex);

      var insertAt = 0;
      insertAt = _indexOf(after);
      widget.steps.insert(insertAt + 1, move);
    });
  }

  void refresh(VoidCallback fn) {
    setState(fn);
  }

  /// Handles the step throwing an exception.
  /// Displays an error and critically calls [entryTarget].cancel on the target
  /// so that we don't lock the UI up.
  Future<void> _safeOnEntry(BuildContext context, WizardStep step,
      WizardStep priorStep, WizardStepTarget entryTarget,
      {required bool userOriginated}) async {
    try {
      await step.onEntry(context, priorStep, entryTarget,
          userOriginated: userOriginated);
      // ignore: avoid_catches_without_on_clauses
    } catch (e, st) {
      if (context.mounted) {
        HMBToast.error(e.toString());
      }
      Log.e(e.toString(), stackTrace: st);
      if (!entryTarget._completer.isCompleted) {
        entryTarget.cancel();
      }
    }
  }

  /// Handles the step throwing an exception.
  /// Displays an error and critically calls [target].cancel on the target
  /// so that we don't lock the UI up.
  Future<void> _safeOnNext(
      BuildContext context, WizardStep step, WizardStepTarget target,
      {required bool userOriginated}) async {
    try {
      await step.onNext(context, target, userOriginated: true);

      // ignore: avoid_catches_without_on_clauses
    } catch (e, st) {
      if (context.mounted) {
        HMBToast.error(e.toString());
      }
      Log.e(e.toString(), stackTrace: st);
      if (!target._completer.isCompleted) {
        target.cancel();
      }
    }
  }

  /// Handles the step throwing an exception.
  /// Displays an error and critically calls [target].cancel on the target
  /// so that we don't lock the UI up.
  Future<void> _safeOnPrev(
      BuildContext context, WizardStep step, WizardStepTarget target,
      {required bool userOriginated}) async {
    try {
      await step.onPrev(context, target, userOriginated: userOriginated);
      // ignore: avoid_catches_without_on_clauses
    } catch (e, st) {
      if (context.mounted) {
        HMBToast.error(e.toString());
      }
      Log.e(e.toString(), stackTrace: st);
      target.cancel();
    }
  }
}

class WizardStepTarget {
  WizardStepTarget(this._wizardstate, this._intendedStep);
  final _completer = CompleterEx<WizardStep>();
  final WizardStep _intendedStep;
  final WizardState _wizardstate;

  void confirm() {
    _completer.complete(_intendedStep);
  }

  void redirect(WizardStep alternateStep) {
    _completer.complete(alternateStep);
  }

  Future<WizardStep> get future => _completer.future;

  /// returns the prior step in the wizard.
  /// Use this with a call to redirect to change the
  /// flow.
  WizardStep? priorStep() => _wizardstate.priorStep();

  /// returns the next step in the wizard.
  /// Use this with a call to redirect to change the
  /// flow.
  WizardStep? nextStep() => _wizardstate.nextStep();

  /// Cancel the transition.
  /// onNext and onPrev will not transition to a
  /// new page if [cancel] is called.
  void cancel() {
    _completer.complete(_wizardstate._currentStep);
  }
}

/// Used when calling 'onNext' on the last step
/// so that the last step has a target step
/// that it can use to indicate success.
class FakeLastStep extends WizardStep {
  FakeLastStep() : super(title: 'FakeLastStep');
  @override
  Widget build(BuildContext context) => const Text('Will never been shown');
}

/// Used to cancel a transition.
// class FakeCancelStep extends WizardStep {
//   FakeCancelStep() : super(title: 'FakeCancelStep');
//   @override
//   Widget build(BuildContext context) {
//     return Text('Will never been shown');
//   }
// }
