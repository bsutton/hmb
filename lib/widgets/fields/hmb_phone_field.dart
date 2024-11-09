import 'package:flutter/material.dart';

import '../dial_widget.dart';

class HMBPhoneField extends StatelessWidget {
  const HMBPhoneField(
      {required this.labelText,
      required this.controller,
      this.validator,
      super.key});

  final TextEditingController controller;
  final String labelText;
  final String? Function(String? value)? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
      controller: controller,
      keyboardType:  TextInputType.phone,
      decoration: InputDecoration(
        labelText: labelText,
        suffixIcon: DialWidget(controller.text),
      ),
      validator: validator);
}
