import 'package:flutter/material.dart';

import '../source_context.dart';
import 'source.dart';

class NoopSource extends Source<String> {
  NoopSource() : super(name: 'text');

  String? text;

  @override
  Widget? widget() => null;

  @override
  String? get value => text;

  @override
  void dependencyChanged(Source<dynamic> source, SourceContext sourceContext) {
    //NOOP
  }

  @override
  void revise(SourceContext sourceContext) {
    // NOOP
  }
}
