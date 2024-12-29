import 'package:flutter/material.dart';

import '../message_template_dialog.dart';
import 'source.dart';

class TextSource extends Source<String> {
  TextSource({required this.label}) : super(name: 'text');

  final String label;
  final controller = TextEditingController();

  String? text;

  @override
  Widget widget(MessageData data) => TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        onChanged: (value) {
          text = value;
        },
      );
}
