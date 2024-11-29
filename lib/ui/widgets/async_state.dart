import 'dart:async';

import 'package:flutter/material.dart';

///
/// [AsyncState] makes it easy to do async initialisation of a [StatefulWidget]
///
/// Instead of [StatefulWidget] deriving from [State] you derive
/// from [AsyncState].
///
/// You can then override the 'asyncInitState' method to do some
/// asynchrounus initialisation.
/// You can see if async initialisation is complete by 
/// check 'initialised'.
/// This is usually passed to a [FutureBuilderEx]:
/// ```dart
/// Widget build(BuildContext context)
/// {
///   return FutureBuilderEx(future: initialised, ....)
/// }
/// ```
/// 
/// Any items that are to be disposed should be called in the standard
/// [initState] as in some cases the [dispose] can be called before 
/// asyncInitState has run.
abstract class AsyncState<T extends StatefulWidget, R> extends State<T> {
  final _initialised = Completer<R>();

  @override
  void initState() {
    super.initState();

    unawaited(asyncInitState().then<R>((r) {
      _initialised.complete(r);
      return r;
    }));
  }

  Future<R> asyncInitState();

  Future<R> get initialised => _initialised.future;
}
