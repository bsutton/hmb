import 'package:flutter/material.dart';

import 'hmb_text_field.dart';

class HMBMoneyField extends HMBTextField {
  const HMBMoneyField(
      {required super.controller,
      required super.labelText,
      super.keyboardType = TextInputType.text,
      super.required = false,
      super.validator,
      super.focusNode,
      super.onChanged,
      super.key,
      super.autofocus = false,
      super.leadingSpace = true});
}
