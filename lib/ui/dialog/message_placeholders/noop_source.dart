import 'package:flutter/material.dart';

import '../message_template_dialog.dart';
import 'source.dart';

class NoopSource extends Source<String> {
  NoopSource() : super(name: 'text');

  String? text;

  @override
  Widget? widget(MessageData data) => null;

  @override
  String? get value => text;
}
