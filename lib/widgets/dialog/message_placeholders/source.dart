import 'package:flutter/material.dart';
import 'package:hmb/widgets/dialog/message_template_dialog.dart';

abstract class Source<T> {
  String name;
  T? value;
  void Function(T? value)? onChanged;

  Source({required this.name});

  Widget field(MessageData data);

  void setValue(T? newValue) {
    value = newValue;
    if (onChanged != null) {
      onChanged!(newValue);
    }
  }
}
