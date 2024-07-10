// ignore_for_file: unused_element

import 'dart:async';

import 'package:completer_ex/completer_ex.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:stacktrace_impl/stacktrace_impl.dart';

import '../util/hmb_theme.dart';
import '../util/stack_list.dart';
import 'hmb_text_themes.dart';
import 'position.dart';
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
/// overlay is enabled by a [BlockingUIRunner].
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

class BlockingOverlay extends StatelessWidget {
  const BlockingOverlay({super.key});
  @override
  Widget build(BuildContext context) => JuneBuilder(BlockingUI.new,
      builder: (blockingUI) => FutureBuilderEx<void>(
          // ignore: discarded_futures
          future: blockingUI.waitForAllActions,
          waitingBuilder: (context) => _BlockingOverlayWidget(blockingUI),
          builder: (context, _) =>
              const SizedBox.shrink() // widget.builder(context),
          ));
}

/// The [_BlockingOverlayWidget] should NOT be used directly.
///
/// It is added to app as an overlay and is
/// activated/displayed as needed by the [BlockingUIRunner].
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
  const _BlockingOverlayWidget(this.blockingUI,
      {super.key,
      this.placement = TopOrTailPlacement.bottom,
      this.hideHelpIcon = true});

  final BlockingUI blockingUI;

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
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    // Log.d(green('is UI blocked ${blockingUI.blocked}'));
    if (widget.blockingUI.blocked) {
      // make it transparent for the first 500ms.

      return TickBuilder(
          limit: 100,
          interval: const Duration(milliseconds: 100),
          builder: (context, index) {
            final showProgress =
                DateTime.now().difference(widget.blockingUI.startTime!) >
                    const Duration(milliseconds: 500);

            // show label if we have been here more than 1 second.
            final showLabel =
                DateTime.now().difference(widget.blockingUI.startTime!) >
                    const Duration(milliseconds: 1000);

            return SizedBox(
                height: height,
                width: width,
                child: Stack(children: [
                  // hide the help icon by drawing a container over it.
                  if (showProgress && widget.hideHelpIcon)
                    Positioned(
                        bottom: 5,
                        right: HMBTheme.padding,
                        child: Container(
                            height: 40,
                            width: 40,
                            color: HMBColors.appBarColor)),
                  // cover the entire screen with an overlay.
                  Positioned(
                      bottom: 0,
                      left: 0,
                      height: height,
                      width: width,
                      child: Opacity(
                          opacity: (showProgress ? 0.6 : 0),
                          child: Container(color: Colors.grey))),

                  // draw the progress indicator
                  if (showProgress)
                    TopOrTail(
                        placement: widget.placement,
                        child: GestureDetector(
                            onTap: cancelRun,
                            child: const CircularProgressIndicator())),
                  if (showLabel)
                    Positioned(
                        bottom: HMBTheme.padding,
                        left: 0,
                        width: width,
                        child: GestureDetector(
                            onTap: cancelRun,
                            child: Center(
                                child: Chip(
                              label: (widget.blockingUI.topAction.label == null
                                  ? HMBTextChip('Just a moment...')
                                  : HMBTextChip('''
Just a moment: ${widget.blockingUI.topAction.label}''')),
                              backgroundColor: Colors.yellow,
                              elevation: 7,
                            ))))
                ]));
          });
    } else {
      return Container();
    }
  }

  void cancelRun() {
    // Log.d('cancel');
  }
}

/// The [slowAction] is called and once it completes the
/// [builder] is called to render the ui.
/// Whilst the [slowAction] is running the [_BlockingOverlayWidget]
/// is displayed.
///
class BlockingUIRunner extends StatefulWidget {
  const BlockingUIRunner(
      {required this.slowAction, required this.builder, this.label, super.key});

  final WidgetBuilder builder;
  final Future<void> Function() slowAction;
  final String? label;

  @override
  State<BlockingUIRunner> createState() => _BlockingUIRunnerState();
}

class _BlockingUIRunnerState extends State<BlockingUIRunner> {
  bool _initialised = false;
  late final CompleterEx<void> completer;

  @override
  void initState() {
    super.initState();
    if (!_initialised) {
      _initialised = true;
      completer = June.getState(BlockingUI.new)
          .run(widget.slowAction, label: widget.label);

      // ignore: discarded_futures
      completer.future.whenComplete(() => setState(() {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (completer.isCompleted) {
      return widget.builder(context);
    } else {
      return Container();
    }
  }
}

class BlockingUI extends JuneState {
  BlockingUI();

  /// manages a possible nested set of calls to [run]
  StackList<ActionRunner<dynamic>> actions = StackList();

  ActionRunner<dynamic> get topAction => actions.peek();

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
    final actionRunner = ActionRunner<T>(label, slowAction, end);

    begin(actionRunner);

    return actionRunner.completer;
  }

  Future<void> _waitForAllActions = Future.value();

  Future<void> get waitForAllActions => _waitForAllActions;

  /// True if any of the actions are still running.
  bool get blocked {
    var blocked = false;
    for (final action in actions.stack) {
      blocked |= action.completer.isCompleted;
    }
    return blocked;
  }

  /// The stack trace of the first action that is blocking the UI.
  StackTrace get stackTrace => actions.peek().stackTrace;

  DateTime? startTime;
  int count = 0;

  ///
  /// begin
  ///
  void begin<T>(ActionRunner<T> actionRunner) {
    actions.push(actionRunner);
    count++;
    // Log.e('begin count=$count');
    // Log.d(green('UI is blocked'));
    // Log.d(green(
    //'blocked by: ${actions.peek().stackTrace.formatStackTrace()}'));

    if (count == 1) {
      startTime = DateTime.now();
    }

    /// start the action.
    actionRunner.start();

    /// Rebuild the future that lets us monitor all runners.
    // ignore:  discarded_futures
    _waitForAllActions = Future.wait<dynamic>(
        actions.stack.map((runner) => runner.completer.future).toList());
    // to ensure we don't try to call set start during a build
    Future.delayed(Duration.zero, refresh);
  }

  ///
  /// end
  ///
  void end() {
    count--;
    assert(count >= 0, 'bad');

    actions.pop();

    // Log.e('end count=$count');
    // Log.d(
    //green('unblocked for: ${callPoint.stackTrace.formatStackTrace()}'));

    if (count == 0) {
      startTime = null;
    }

    /// refresh so the label can be updated or if there are
    /// no remaining actions then the UI can be unblocked.
    // to ensure we don't try to call set start during a build
    Future.delayed(Duration.zero, refresh);
  }
}

/// [BlockingUI] support nested calls to its [BlockingUI.run] method.
/// To managed this we need to maintain a stack of calls
/// to the [BlockingUI.run] method so we can display the [label] of the
/// [BlockingUI.run] method that is currently on top of the stack.
/// We also maintaine a list of [StackTraceImpl] in [stackTrace]
/// so that we can dump call point stack traces for debugging
/// purposes.
class ActionRunner<T> {
  ActionRunner(this.label, this.slowAction, this.end)
      : stackTrace = StackTraceImpl(skipFrames: 2);
  final String? label;

  final Future<T> Function() slowAction;
  void Function() end;

  final completer = CompleterEx<T>();

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
      completer.complete();
      end();
    });
  }
}
