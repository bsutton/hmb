import 'package:flutter/material.dart';

import '../message_template_dialog.dart';
import 'place_holder.dart';

abstract class Source<T> {
  Source({required this.name});
  String name;
  void Function(T? value, ResetFields resetFields)? onChanged;

  Widget? widget(MessageData data);

  T? get value;
}
