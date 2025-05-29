// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';

import 'package:completer_ex/completer_ex.dart';
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:stacktrace_impl/stacktrace_impl.dart';

import '../../util/hmb_theme.dart';
import '../../util/stack_list.dart';
import 'color_ex.dart';
import 'layout/position.dart';
import 'text/hmb_text_themes.dart';
import 'tick_builder.dart';

///
/// Provides a progress indicator for actions that can
/// take an extended time to complete.
///
/// We block the UI from user interaction
/// and put up a waiting indicator if the action
/// takes more than 300 ms.
///
/// The [BlockingOverlay] takes up zero space until the
/// overlay is enabled by a [BlockingUITransition].
///
/// To use this class you must addd a BlockingUI provider
/// in your main:
///
/// ```dart
///   runApp(Column(
///   children: [
///      BlockingOverlay(),
///      RealUI(builder: (context) BlockingUIRunner(
///          slowAction: _initialise,
///          label: 'Upgrade your database.',
///          builder: (context) =>
///              const HomeWithDrawer(initialScreen: JobListScreen()),))
///   ],
/// ));
/// ```
///
/// Example:
/// ```dart
/// class X {
///   Future<void> onLoad() async {
///     final user = await BlockingUI().run<User>(() =>  rest.getUser();
///     showUser(user);
///     });
///   }
///
///   Future<void> onSave() async {
///     await BlockingUI().run<void>(() => rest.saveUser(user);
///   }
/// }
/// ```
///

///
/// Use this builder when you need to build a component that
/// is slow to build. It will display a [_BlockingOverlayWidget]
/// whilst the new UI is built.
///
/// We typically use this when transitioning to a new full
/// screen component.
/// If the full screen component takes less than 500ms
/// to build you will not see the blocking UI.
///
/// Refer to [_BlockingOverlayWidget] for the full set of rules as to
/// when/how the blocking UI is presented.
///

/// Use this method to trigger a rebuild of the [BlockingOverlay]

class BlockingOverlay extends StatelessWidget {
  const BlockingOverlay({super.key});
  @override
  Widget build(BuildContext context) => JuneBuilder(
    BlockingOverlayState.new,
    builder: (blockingOverlayState) => FutureBuilderEx<void>(
      debugLabel: 'BlockingOverlayState',
      // ignore: discarded_futures
      future: blockingOverlayState.waitForAllActions,
      waitingBuilder: (context) => _BlockingOverlayWidget(blockingOverlayState),
      builder: (context, _) =>
          const SizedBox.shrink(), // widget.builder(context),
    ),
  );
}

/// The [_BlockingOverlayWidget] should NOT be used directly.
///
/// It is added to app as an overlay and is
/// activated/displayed as needed by the [BlockingUITransition].
///
/// Displays the standard blocking UI widget which is
/// The widget is not visible for the first 500 ms
/// From 500 - 1000ms it shows the 'progress' indicator and greys the background
/// From 1000ms to completion it shows a label 'Just a moment...'
///
class _BlockingOverlayWidget extends StatefulWidget {
  /// [placement] controls where the spinning placement indicator goes
  /// We normally use [TopOrTailPlacement.top] during the Registration
  /// Wizard and
  /// [TopOrTailPlacement.bottom] at all other times.
  /// [hideHelpIcon] defaults to true and should be used when using the
  ///  [TopOrTailPlacement.bottom]
  /// placement otherwise you can see the help icon below the
  ///  progress indicator.
  const _BlockingOverlayWidget(
    this.blockingOverlayState, {
    super.key,
    this.placement = TopOrTailPlacement.bottom,
    this.hideHelpIcon = true,
  });

  final BlockingOverlayState blockingOverlayState;

  final TopOrTailPlacement placement;
  final bool hideHelpIcon;

  @override
  State<StatefulWidget> createState() => _BlockingOverlayWidgetState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<TopOrTailPlacement>('placement', placement))
      ..add(DiagnosticsProperty<bool>('hideHelpIcon', hideHelpIcon));
  }
}

///
/// Displays an full screen transparent container
/// which blocks any user interaction.
///
class _BlockingOverlayWidgetState extends State<_BlockingOverlayWidget> {
  @override
  Widget build(BuildContext context) {
    if (!widget.blockingOverlayState.blocked) {
      return const SizedBox.shrink();
    }
    return Material(
      type: MaterialType.transparency, // ensures no background is painted
      child: TickBuilder(
        limit: 100,
        interval: const Duration(milliseconds: 100),
        builder: (context, index) {
          final elapsed = DateTime.now().difference(
            widget.blockingOverlayState.startTime!,
          );
          final showProgress = elapsed > const Duration(milliseconds: 500);
          final showLabel = elapsed > const Duration(milliseconds: 1000);

          return Stack(
            children: [
              // Use ModalBarrier for a translucent overlay
              Positioned.fill(
                child: ModalBarrier(
                  color: showProgress
                      ? Colors.grey.withSafeOpacity(0.6)
                      : Colors.transparent,
                  dismissible: false,
                ),
              ),
              // Show the progress indicator when appropriate
              if (showProgress)
                Center(
                  child: GestureDetector(
                    onTap: cancelRun,
                    child: const CircularProgressIndicator(),
                  ),
                ),
              // Display a waiting label after 1 second
              if (showLabel)
                Positioned(
                  bottom: HMBTheme.padding,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Chip(
                      label: widget.blockingOverlayState.topAction.label == null
                          ? HMBTextChip('Just a moment...')
                          : HMBTextChip(
                              'Just a moment: ${widget.blockingOverlayState.topAction.label}',
                            ),
                      backgroundColor: Colors.yellow,
                      elevation: 7,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void cancelRun() {
    // Log.d('cancel');
  }
}

typedef ErrorBuilder = Widget Function(BuildContext, Object error);

/// This class is designed to provide user feedback
/// when transition to a new screen that may take some
/// time.
/// The [slowAction] is called and once it completes the
/// [builder] is called to render the ui.
///
/// If the  [slowAction] takes more than 500ms to complete
/// the  [_BlockingOverlayWidget] is displayed.
///
///
class BlockingUITransition<T> extends StatefulWidget {
  const BlockingUITransition({
    required this.slowAction,
    required this.builder,
    this.errorBuilder,
    this.label,
    super.key,
  });

  final BlockingWidgetBuilder<T> builder;
  final ErrorBuilder? errorBuilder;
  final Future<T> Function() slowAction;
  final String? label;

  @override
  State<BlockingUITransition<T>> createState() =>
      BlockingUITransitionState<T>();
}

typedef BlockingWidgetBuilder<T> =
    Widget Function(BuildContext context, T? data);

class BlockingUITransitionState<T>
    extends DeferredState<BlockingUITransition<T>> {
  var _initialised = false;
  late final CompleterEx<T> completer;

  Object? _error;

  T? data;

  @override
  Future<void> asyncInitState() async {
    if (!_initialised) {
      _initialised = true;

      // start the blocking UI
      completer = BlockingUI().run(widget.slowAction, label: widget.label);

      try {
        // await your slow action
        data = await completer.future;
      } catch (e) {
        _error = e;
      }
    }
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) {
      if (completer.isCompleted) {
        if (_error == null) {
          return widget.builder(context, data);
        } else {
          return widget.errorBuilder?.call(context, _error!) ??
              widget.builder(context, data);
        }
      } else {
        // initiallly we display a blank screen until the
        // ticker kicks in and displays the waiting message.
        // This helps reduce flicker for very short lived actions.
        return Container();
      }
    },
  );
}

class BlockingOverlayState extends JuneState {
  /// manages a possible nested set of calls to [begin]/[end]
  StackList<RunningSlowAction<dynamic>> actions = StackList();

  RunningSlowAction<dynamic> get topAction => actions.peek();

  Future<void> _waitForAllActions = Future.value();

  Future<void> get waitForAllActions => _waitForAllActions;

  /// True if any of the actions are still running.
  bool get blocked {
    var blocked = false;
    for (final action in actions.stack) {
      blocked |= !action.completer.isCompleted;
    }
    return blocked;
  }

  /// The stack trace of the first action that is blocking the UI.
  StackTrace get stackTrace => actions.peek().stackTrace;

  DateTime? startTime;
  var _count = 0;

  ///
  /// begin
  ///
  void begin<T>(RunningSlowAction<T> actionRunner) {
    actions.push(actionRunner);
    _count++;
    // Log.e('begin count=$count');
    // Log.d(green('UI is blocked'));
    // Log.d(green(
    //'blocked by: ${actions.peek().stackTrace.formatStackTrace()}'));

    if (_count == 1) {
      startTime = DateTime.now();
    }

    /// start the action.
    actionRunner.start();

    /// Rebuild the future that lets us monitor all runners.
    // ignore:  discarded_futures
    _waitForAllActions = Future.wait<dynamic>(
      actions.stack.map((runner) => runner.completer.future).toList(),
    );
    rebuildOverlay();
  }

  ///
  /// end
  ///
  void end() {
    _count--;
    assert(_count >= 0, 'bad');

    actions.pop();

    // Log.e('end count=$count');
    // Log.d(
    //green('unblocked for: ${callPoint.stackTrace.formatStackTrace()}'));

    if (_count == 0) {
      startTime = null;
      _waitForAllActions = Future.value();
    } else {
      // ignore: discarded_futures
      _waitForAllActions = Future.wait<dynamic>(
        actions.stack.map((runner) => runner.completer.future).toList(),
      );
    }

    /// refresh so the label can be updated or if there are
    /// no remaining actions then the UI can be unblocked.
    rebuildOverlay();
  }

  void rebuildOverlay() {
    // Delayed to ensure we don't try to call [rebuildOverlay] during a build
    Future.delayed(
      Duration.zero,
      () => June.getState(BlockingOverlayState.new).setState(),
    );
  }
}

class BlockingUI {
  BlockingUI();

  /// Executes a long running function asking the user to wait
  /// if necessary.
  ///
  /// The [label] can be provided to inform the user what action is
  /// holding things up. The [label] is displayed after the text:
  /// 'Just a moment'.
  /// As such the action should be a short verb e.g. Saving.
  /// example
  ///
  /// If your function returns a future then use:
  /// ```dart
  /// Data x = BlockingUIRunner().run<Data>(() => slowaction, action: 'Saving');
  /// ```
  /// If your function doesn't return a future then use: (note the use of async)
  /// ```dart
  /// Data x = BlockingUIRunner().run<Data>(() async => slowaction,
  /// action: 'Saving');
  ///
  /// If [func] needs to return a null it must still return a future by using:
  /// Future.value(null);
  /// ```
  CompleterEx<T> run<T>(Future<T> Function() slowAction, {String? label}) {
    final overlay = June.getState(BlockingOverlayState.new);
    final actionRunner = RunningSlowAction<T>(label, slowAction, overlay.end);

    overlay.begin(actionRunner);

    return actionRunner.completer;
  }

  /// Convience method for [run] that allows you to wait for the
  /// long running [slowAction] to complete.
  Future<T> runAndWait<T>(Future<T> Function() slowAction, {String? label}) =>
      run(slowAction, label: label).future;
}

/// [BlockingUI] supports nested calls to its [BlockingUI.run]
/// method.
/// To managed this we need to maintain a stack of calls
/// to the [BlockingUI.run] method so we can display the [label] of the
/// [BlockingUI.run] method that is currently on top of the stack.
/// We also maintain a list of [StackTraceImpl] in [stackTrace]
/// so that we can dump call site stack traces for debugging
/// purposes.
class RunningSlowAction<T> {
  RunningSlowAction(this.label, this.slowAction, this.end)
    : completer = CompleterEx<T>(debugName: label),
      stackTrace = StackTraceImpl(skipFrames: 2);
  final String? label;

  final Future<T> Function() slowAction;
  void Function() end;

  final CompleterEx<T> completer;

  /// The stack trace of where the [BlockingUI.run] method was called from.
  StackTraceImpl stackTrace;

  void start() {
    // Now call the long running function.
    // ignore: discarded_futures
    final result = slowAction();
    // if this fails you probably need to use return Future.value(null);
    result
        // ignore: discarded_futures, invalid_return_type_for_catch_error
        .catchError(completer.completeError)
        // ignore: discarded_futures
        .whenComplete(() {
          /// If an error occurs we will aready be complete.
          if (!completer.isCompleted) {
            completer.complete(result);
          }
          end();
        });
  }
}
