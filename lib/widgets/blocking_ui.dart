// ignore_for_file: unused_element

import 'dart:async';

import 'package:completer_ex/completer_ex.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:provider/provider.dart';
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
/// To use this class you must addd a BlockingUI provider
/// in your main:
///
/// ```dart
///   runApp(ChangeNotifierProvider(
///   create: (_) => BlockingUI(),
///   child: const MyApp(),
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

class BlockingUI extends ChangeNotifier {
  factory BlockingUI() {
    _self ??= BlockingUI._internal();
    return _self!;
  }

  BlockingUI._internal();
  static BlockingUI? _self;
  DateTime? startTime;
  int count = 0;

  /// manages a possible nested set of calls to [run]
  StackList<RunCallPoint> actions = StackList();

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
  /// Data x = BlockingUI().run<Data>(() => slowaction, action: 'Saving');
  /// ```
  /// If your function doesn't return a future then use: (note the use of async)
  /// ```dart
  /// Data x = BlockingUI().run<Data>(() async => slowaction, action: 'Saving');
  ///
  /// If [func] needs to return a null it must still return a future by using:
  /// Future.value(null);
  /// ```
  Future<T> run<T>(Future<T> Function() func, {String? label}) {
    final completer = CompleterEx<T>();
    begin(label);
    // Now call the long running function.
    final result = func();
    // if this fails you probably need to use return Future.value(null);
    result
        .then(completer.complete)
        .catchError(completer.completeError)
        .whenComplete(end);
    return completer.future;
  }

  // Block the ui until the given [future] completes.
  /// If the [future] completes successfully then [onDone]
  /// is called otherwise [onError] is called.
  Future<void> blockUntilFuture<T>(Future<T> Function() future,
      {void Function(T)? onDone,
      void Function(Object)? onError,
      String? label}) async {
    // Call run and await for the passed future to complete
    await run<T>(
        () async => future().then((t) {
              onDone?.call(t);
              return t;
            },
                // ignore: avoid_types_on_closure_parameters
                onError: (Object e, StackTrace st) {
              onError?.call(e);
              // Log().e('''
// blockUntilFuture returned an error
//$e st: ${StackTraceImpl.fromStackTrace(st).formatStackTrace()}''');
            }),
        label: label);
  }

  void begin(String? label) {
    actions.push(RunCallPoint(label));
    count++;
    // Log.e('begin count=$count');
    // Log.d(green('UI is blocked'));
    // Log.d(green(
    //'blocked by: ${actions.peek().stackTrace.formatStackTrace()}'));

    if (count == 1) {
      startTime = DateTime.now();
      notifyListeners();
    }
  }

  void end() {
    count--;
    assert(count >= 0, 'bad');

    actions.pop();

    // Log.e('end count=$count');
    // Log.d(
    //green('unblocked for: ${callPoint.stackTrace.formatStackTrace()}'));

    if (count == 0) {
      startTime = null;
      notifyListeners();
    }
  }

  RunCallPoint get action => actions.peek();

  bool get blocked => count > 0;
}

///
/// Use this builder when you need to build a component that
/// is slow to build. It will display a [_BlockingUIWidget]
/// whilst the new UI is built.
///
/// We typically use this when transitioning to a new full
/// screen component.
/// If the full screen component takes less than 500ms
/// to build you will not see the blocking UI.
///
/// Refer to [_BlockingUIWidget] for the full set of rules as to
/// when/how the blocking UI is presented.
///
/// The [future] is called and once it completes the
/// [builder] is called to render the ui.
/// Whilst the [future] is running the [_BlockingUIWidget]
/// is displayed.
///
class BlockingUIBuilder<T> extends StatelessWidget {
  const BlockingUIBuilder(
      {required this.future,
      required this.builder,
      required this.stacktrace,
      this.label,
      super.key});
  final Future<T> Function() future;
  final CompletedBuilder<T> builder;
  final StackTrace stacktrace;
  final String? label;

  @override
  Widget build(BuildContext context) => FutureBuilderEx<T>(
        // ignore: discarded_futures
        future: Future.delayed(
            // delay the call to run until the build is complete to
            // avoid a flutter error that can occure if you call
            //set state whilst a build is already running.
            Duration.zero,
            () async => BlockingUI().run(future, label: label)),
        waitingBuilder: (context) => const _BlockingUIWidget(),
        builder: builder,
      );
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ObjectFlagProperty<CompletedBuilder<T>>.has('builder', builder))
      ..add(DiagnosticsProperty<StackTrace>('stacktrace', stacktrace))
      ..add(ObjectFlagProperty<Future<T> Function()>.has('future', future));
  }
}

/// The [_BlockingUIWidget] should NOT be used directly.
///
/// It is added to app as an overlay and is
/// activated/displayed as needed by the [BlockingUI.run], [BlockingUI.blockUntilFuture] and
/// [BlockingUIBuilder] as needed.
///
/// Displays the standard blocking UI widget which is
/// The widget is not visible for the first 500 ms
/// From 500 - 1000ms it shows the 'progress' indicator and greys the background
/// From 1000ms to completion it shows a label 'Just a moment...'
///
class _BlockingUIWidget extends StatefulWidget {
  /// [placement] controls where the spinning placement indicator goes
  /// We normally use [TopOrTailPlacement.top] during the Registration
  /// Wizard and
  /// [TopOrTailPlacement.bottom] at all other times.
  /// [hideHelpIcon] defaults to true and should be used when using the
  ///  [TopOrTailPlacement.bottom]
  /// placement otherwise you can see the help icon below the
  ///  progress indicator.
  const _BlockingUIWidget(
      {super.key,
      this.placement = TopOrTailPlacement.bottom,
      this.hideHelpIcon = true});
  final TopOrTailPlacement placement;
  final bool hideHelpIcon;
  @override
  State<StatefulWidget> createState() => _BlockingUIWidgetState();
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
class _BlockingUIWidgetState extends State<_BlockingUIWidget> {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Consumer<BlockingUI>(builder: (context, blockingUI, _) {
      // Log.d(green('is UI blocked ${blockingUI.blocked}'));
      if (blockingUI.blocked) {
        // make it transparent for the first 500ms.

        return TickBuilder(
            limit: 100,
            interval: const Duration(milliseconds: 100),
            builder: (context, index) {
              final showProgress =
                  DateTime.now().difference(blockingUI.startTime!) >
                      const Duration(milliseconds: 500);

              // show label if we have been here more than 1 second.
              final showLabel =
                  DateTime.now().difference(blockingUI.startTime!) >
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
                          // height: 20,
                          child: GestureDetector(
                              onTap: cancelRun,
                              child: Center(
                                  child: Chip(
                                label: (blockingUI.action.label == null
                                    ? HMBTextChip('Just a moment...')
                                    : HMBTextChip('''
Just a moment: ${blockingUI.action.label}''')),
                                backgroundColor: Colors.yellow,
                                elevation: 7,
                              ))))
                  ]));
            });
      } else {
        return Container();
      }
    });
  }

  void cancelRun() {
    // Log.d('cancel');
  }
}

/// [BlockingUI] support nested calls to its [BlockingUI.run] method.
/// To managed this we need to maintain a stack of calls
/// to the [BlockingUI.run] method so we can display the [label] of the
/// [BlockingUI.run] method that is currently on top of the stack.
/// We also maintaine a list of [StackTraceImpl] in [stackTrace]
/// so that we can dump call point stack traces for debugging
/// purposes.
class RunCallPoint {
  RunCallPoint(this.label) : stackTrace = StackTraceImpl(skipFrames: 2);
  String? label;

  /// The stack trace of where the [BlockingUI.run] method was called from.
  StackTraceImpl stackTrace;
}
