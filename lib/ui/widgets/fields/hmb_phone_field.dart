import 'package:flutter/material.dart';

import '../../../ui/widgets/dial_widget.dart';
import '../../dialog/message_template_dialog.dart';

class HMBPhoneField extends StatelessWidget {
  const HMBPhoneField(
      {required this.labelText,
      required this.controller,
      required this.messageData,
      this.validator,
      super.key});

  final TextEditingController controller;
  final String labelText;
  final String? Function(String? value)? validator;
  final MessageData messageData;

  @override
  Widget build(BuildContext context) => TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: labelText,
        suffixIcon: DialWidget(controller.text, messageData: messageData),
      ),
      validator: validator);
}
