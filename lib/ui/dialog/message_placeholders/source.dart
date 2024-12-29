import 'package:flutter/material.dart';

import '../message_template_dialog.dart';
import 'place_holder.dart';

abstract class Source<T> {
  Source({required this.name});
  String name;
  T? value;
  void Function(T? value, ResetFields resetFields)? onChanged;

  Widget? widget(MessageData data);

  // ignore: use_setters_to_change_properties
  void setValue(T? newValue) {
    value = newValue;
    // if (onChanged != null) {
    //   onChanged!(newValue, );
    // }
  }
}
