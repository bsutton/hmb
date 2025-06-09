import 'dart:async';

import 'package:completer_ex/completer_ex.dart';
import 'package:flutter/material.dart';

import '../../util/hmb_theme.dart';
import '../../util/log.dart';
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
  backedOut, // The user clicked the hardware back button and exited the wizard.
}

typedef WizardCompletion = Future<void> Function(WizardCompletionReason reason);

/// Called each time the wizard is about to transition.
/// The transition can be triggered via an API call or a user action.
/// The argument [userOriginated] is true if it was caused by a user action.
/// The [currentStep] is the step the wizard is currently showing
/// when the transition started.
/// The [targetStep] is the step the wizard is moving to.
typedef Transition =
    void Function({
      required WizardStep currentStep,
      required WizardStep targetStep,
      required bool userOriginated,
    });

/// Build multi-step wizards.
/// [initialSteps] the set of states the wizard starts with.
class Wizard extends StatefulWidget {
  Wizard({
    required this.initialSteps,
    super.key,
    this.onTransition,
    this.onFinished,
    this.cancelLabel = 'Cancel',
  }) : assert(initialSteps.isNotEmpty, 'Must have at least one step');

  final WizardCompletion? onFinished;
  final Transition? onTransition;
  final List<WizardStep> initialSteps;
  final String cancelLabel;

  @override
  State<Wizard> createState() => WizardState();
}

class WizardState extends State<Wizard> {
  static const double lineInset = 7;
  static const double lineWidth = 24;
  static const crossFadeDuration = Duration(milliseconds: 500);
  final _scrollController = ScrollController();

  final ScrollPhysics physics = const ClampingScrollPhysics();

  late final List<WizardStep> steps;
  late final List<GlobalKey> _keys;

  late WizardStep _currentStep;
  var _currentStepIndex = 0;

  var _onFinishCalled = false;
  final _pageLoading = false;
  final _inTransition = false;

  Future<void> _popInvoked(BuildContext context) async {
    if (!isFirstVisible(_currentStepIndex)) {
      await _onBack();
    } else {
      await _triggerOnFinished(WizardCompletionReason.backedOut);
    }
  }

  @override
  void initState() {
    super.initState();

    steps = [...widget.initialSteps];
    for (final step in steps) {
      step.wizardState = this;
    }

    _currentStep = steps[0];
    _currentStepIndex = 0;

    _keys = List<GlobalKey>.generate(steps.length, (i) => GlobalKey());
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: isFirstVisible(_currentStepIndex),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) {
        await _popInvoked(context);
      }
    },
    child: Material(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _buildBody()),
          _buildControls(),
        ],
      ),
    ),
  );

  Future<void> _onNext() async {
    BlockingUI().run(() async {
      if (isLastVisible(_currentStepIndex)) {
        final fakeLast = FakeLastStep();
        final target = WizardStepTarget(this, fakeLast);

        await _safeOnNext(
          context,
          _currentStep,
          target,
          userOriginated: true,
        ); // might redirect

        final result = await target.future;
        if (result == fakeLast) {
          await _triggerOnFinished(WizardCompletionReason.completed);
        }
      } else {
        final next = _nextStep(_currentStepIndex);
        if (next != null) {
          await _transitionForward(next, userOriginated: true);
        }
      }
    });
  }

  Future<void> _onBack() async {
    BlockingUI().run<void>(() async {
      final prior = _priorStep(_currentStepIndex);
      if (prior != null) {
        await _transitionBackwards(prior, userOriginated: true);
      }
    });
  }

  Future<void> _transitionForward(
    WizardStep targetStep, {
    required bool userOriginated,
  }) async {
    _hideKeyboard();

    final transitionTarget = WizardStepTarget(this, targetStep);
    await _safeOnNext(
      context,
      _currentStep,
      transitionTarget,
      userOriginated: userOriginated,
    );

    var nextStep = await transitionTarget.future;
    if (nextStep == _currentStep) {
      // user canceled or stayed - we are not moving.
      Log.d('_transitionForward rejected by onNext');
      return;
    }

    // if user redirected us backwards, handle that
    if (!isAfter(nextStep)) {
      await _transitionBackwards(nextStep, userOriginated: userOriginated);
      return;
    }

    // try stepping forward
    WizardStep? tryStep;
    var firstpass = true;
    do {
      // first pass we use nextStep acquired above.
      if (firstpass) {
        firstpass = false;
      } else {
        // nextStep was updated
        if (!isAfter(tryStep!)) {
          await _transitionBackwards(tryStep, userOriginated: userOriginated);
          return;
        }
        nextStep = tryStep;
      }

      final entryTarget = WizardStepTarget(this, nextStep);
      if (mounted) {
        await _safeOnEntry(
          context,
          nextStep,
          _currentStep,
          entryTarget,
          userOriginated: userOriginated,
        );
      }
      tryStep = await entryTarget.future;
    } while (nextStep != tryStep);

    // onEntry is happy to let us in.
    widget.onTransition?.call(
      currentStep: _currentStep,
      targetStep: nextStep,
      userOriginated: userOriginated,
    );

    _currentStep = nextStep;
    _currentStepIndex = _indexOf(nextStep);
    await _showStep();
  }

  Future<void> _transitionBackwards(
    WizardStep targetStep, {
    required bool userOriginated,
  }) async {
    _hideKeyboard();

    // Check if we can transition and get the new step
    // as onBack can redirect us.

    final transitionTarget = WizardStepTarget(this, targetStep);
    await _safeOnPrev(
      context,
      _currentStep,
      transitionTarget,
      userOriginated: userOriginated,
    );

    var prevStep = await transitionTarget.future;
    if (prevStep == _currentStep) {
      // we are not moving.
      Log.d('_transitionBackwards rejected by onPrev');
      return;
    }

    // if user is sending us forward from onPrev
    if (isAfter(prevStep)) {
      await _transitionForward(prevStep, userOriginated: userOriginated);
      return;
    }

    // try stepping backward
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

      final entryTarget = WizardStepTarget(this, prevStep);
      if (mounted) {
        await _safeOnEntry(
          context,
          prevStep,
          _currentStep,
          entryTarget,
          userOriginated: userOriginated,
        );
      }
      tryStep = await entryTarget.future;
    } while (prevStep != tryStep);

    // onEntry is happy to let us in.
    widget.onTransition?.call(
      currentStep: _currentStep,
      targetStep: prevStep,
      userOriginated: userOriginated,
    );

    _currentStep = prevStep;
    _currentStepIndex = _indexOf(prevStep);
    await _showStep();
  }

  /// Allows you to force a jump to a specific step.
  /// By default we check each intermediate step to confirm that it can be
  /// skipped (by calling [jumpToStep].canSkip on each step).
  /// If one of the intermediate steps can't be skipped then the wizard
  /// will display that page calling its onEntry method.
  ///
  /// You can bypass the skip check by passing [checkCanSkip:false].
  ///
  Future<void> jumpToStep(
    WizardStep jumpToStep, {
    required bool userOriginated,
    bool checkCanSkip = true,
  }) async {
    BlockingUI().run<void>(() async {
      if (!jumpToStep.isActive ||
          jumpToStep == _currentStep ||
          jumpToStep.hidden) {
        return;
      }
      if (isAfter(jumpToStep)) {
        Log.d('wizard jump forward');
        // we are moving forward so
        // check each intermediary step to ensure that it can be skipped.
        if (checkCanSkip) {
          var idx = _currentStepIndex;
          WizardStep? s;
          do {
            if (s != null) {
              Log.d('skipping ${s.title}');
            }
            s = _nextStep(idx);
            if (s == null) {
              return;
            }
            idx = _indexOf(s);
          } while (s.canSkip(context) &&
              !isLastVisible(idx) &&
              s != jumpToStep);
        }
        await _transitionForward(jumpToStep, userOriginated: userOriginated);
      } else {
        // jump backward
        await _transitionBackwards(jumpToStep, userOriginated: userOriginated);
      }
    });
  }

  // remove the onscreen keyboard.
  void _hideKeyboard() => FocusScope.of(context).unfocus();

  Future<void> _showStep() async {
    setState(() {
      // force a rebuild of the steps
    });

    // We need to scroll to the newly tapped step.
    // The delay is so the cross fade has a chance to complete.
    // This is a little hack, but there is no apparent way to hook
    // the cross fade completion so we just share a common duration.
    Future.delayed(crossFadeDuration, () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    });

    // if (_scrollController.hasClients) {
    //   await _scrollController.animateTo(
    //     0,
    //     duration: const Duration(milliseconds: 300),
    //     curve: Curves.easeOut,
    //   );
    // }
  }

  Widget _buildBody() {
    final steps = _buildSteps();
    return ListView(
      controller: _scrollController,
      shrinkWrap: true,
      physics: physics,
      children: steps,
    );
  }

  Widget _buildStepHeading(WizardStep step, int stepNo) => GrayedOut(
    grayedOut: step != _currentStep,
    child: Row(children: [_buildNo(stepNo), step.title]),
  );

  Widget _buildNo(int stepNo) => SizedBox(
    height: 60,
    child: Column(
      children: [
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
              ),
            ),
          ),
        ),
        _buildLine(!isLastVisible(stepNo)),
      ],
    ),
  );

  Widget _buildLine(bool visible) => Container(
    width: visible ? 2.0 : 0.0,
    height: 11,
    color: Colors.grey.shade400,
  );

  /// Show the step's build if it's the current step; otherwise show a placeholder.
  Widget buildStepBody(WizardStep step, int index) {
    final isCurrentStep = _isCurrent(index);

    if (isCurrentStep) {
      final width = MediaQuery.of(context).size.width - lineInset - lineWidth;
      return SizedBox(width: width, child: step.build(context));
    } else {
      // If not current, collapse or show nothing
      return const SizedBox.shrink();
    }
  }

  void dipose() {
    for (final step in widget.initialSteps) {
      step.dispose();
    }
  }

  List<Widget> _buildSteps() {
    final children = <Widget>[];

    var stepNo = 0;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.hidden) {
        continue;
      }
      children.add(
        Column(
          key: _keys[i],
          children: [
            Material(
              child: InkWell(
                onTap: () => unawaited(jumpToStep(step, userOriginated: true)),
                child: _buildStepHeading(step, stepNo),
              ),
            ),
            _buildVerticalBody(step, i),
          ],
        ),
      );
      stepNo++;
    }
    return children;
  }

  Widget _buildVerticalBody(WizardStep step, int index) => Align(
    alignment: Alignment.centerLeft,
    child: Stack(
      children: [
        // vertical line on the left side
        PositionedDirectional(
          start: lineInset,
          top: 0,
          bottom: 0,
          child: SizedBox(
            width: lineWidth,
            child: Center(
              child: SizedBox(
                width: isLastVisible(index) ? 0.0 : 2.0,
                child: Container(color: Colors.grey.shade400),
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
            margin: const EdgeInsetsDirectional.only(start: 30),
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.centerLeft,
              // Build the step's real widget if this step is current
              child: buildStepBody(step, index),
            ),
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
    ),
  );

  ///
  /// BUILD CONTROLS
  ///
  Widget _buildControls() => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        HMBButtonSecondary(
          label: widget.cancelLabel,
          onPressed: _inTransition || _pageLoading
              ? null
              : () async {
                  await _triggerOnFinished(WizardCompletionReason.cancelled);
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
          onPressed: _inTransition || _pageLoading ? null : _onNext,
        ),
      ],
    ),
  );

  ///
  /// STEP NAVIGATION
  ///
  bool isFirstVisible(int index) => index == _firstVisible();

  /// Returns the index of the first step that is currently visible
  int _firstVisible() {
    var index = 0;
    while (index < steps.length && steps[index].hidden) {
      index++;
    }
    return index;
  }

  /// Returns true if the given [index] is the index of the
  /// last step that is visible i.e. not hidden.
  bool isLastVisible(int index) => index == _lastVisible();

  /// Returns the index of the last step that is currently visible
  int _lastVisible() {
    var index = steps.length - 1;
    while (index >= 0 && steps[index].hidden) {
      index--;
    }
    return index;
  }

  bool _isCurrent(int index) => index == _currentStepIndex;

  /// Searches forward through the set of steps until
  /// it finds an active and visible step
  /// Returns null if no active next step exists.
  WizardStep? _nextStep(int currentStepIndex) {
    do {
      currentStepIndex++;
      if (currentStepIndex >= steps.length) {
        return null;
      }
    } while (!steps[currentStepIndex].isActive ||
        steps[currentStepIndex].hidden);
    return steps[currentStepIndex];
  }

  /// Searches backward through the set of steps until
  /// it finds an active and visible step
  /// Returns null if no prior step exists.
  WizardStep? _priorStep(int currentStepIndex) {
    do {
      currentStepIndex--;
      if (currentStepIndex < 0) {
        return null;
      }
    } while (!steps[currentStepIndex].isActive ||
        steps[currentStepIndex].hidden);
    return steps[currentStepIndex];
  }

  bool isAfter(WizardStep step) => _indexOf(step) > _currentStepIndex;
  int _indexOf(WizardStep step) {
    final idx = steps.indexOf(step);
    if (idx < 0) {
      throw ArgumentError.value(step, 'step not found in wizard steps');
    }
    return idx;
  }

  void reorderStep({required WizardStep move, required WizardStep after}) {
    setState(() {
      final removeIndex = _indexOf(move);
      steps.removeAt(removeIndex);
      final insertAt = _indexOf(after);
      steps.insert(insertAt + 1, move);
    });
  }

  void refresh(VoidCallback fn) {
    setState(fn);
  }

  /// Handles the step throwing an exception.
  /// Displays an error and critically calls [entryTarget].cancel on the target
  /// so that we don't lock the UI up.
  Future<void> _safeOnEntry(
    BuildContext context,
    WizardStep step,
    WizardStep priorStep,
    WizardStepTarget entryTarget, {
    required bool userOriginated,
  }) async {
    try {
      await step.onEntry(
        context,
        priorStep,
        entryTarget,
        userOriginated: userOriginated,
      );
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
    BuildContext context,
    WizardStep step,
    WizardStepTarget target, {
    required bool userOriginated,
  }) async {
    try {
      await step.onNext(context, target, userOriginated: userOriginated);

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
    BuildContext context,
    WizardStep step,
    WizardStepTarget target, {
    required bool userOriginated,
  }) async {
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

  Future<void> _triggerOnFinished(WizardCompletionReason reason) async {
    /// Stops onFinished being called recursively.
    /// This can occur if during onFinish processing
    /// Navigation.pop is called which we trap and then
    /// try to call onFinished a second time which
    /// always ends baddly.
    if (_onFinishCalled) {
      return;
    }
    _onFinishCalled = true;
    await widget.onFinished?.call(reason);
    _onFinishCalled = false;
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
  WizardStep? priorStep() =>
      _wizardstate._priorStep(_wizardstate._currentStepIndex);

  /// returns the next step in the wizard.
  /// Use this with a call to redirect to change the
  /// flow.
  WizardStep? nextStep() =>
      _wizardstate._nextStep(_wizardstate._currentStepIndex);

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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
