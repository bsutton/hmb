// ignore_for_file: avoid_classes_with_only_static_members

import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class HMBToast {
  static void info(String text) {
    toastification.show(
        type: ToastificationType.info,
        style: ToastificationStyle.minimal,
        autoCloseDuration: const Duration(seconds: 6),
        description: Text(
          text,
          maxLines: 6,
        ));
  }

  static void error(String text, {bool acknowledgmentRequired = false}) {
    toastification.show(
      type: ToastificationType.error,
      style: ToastificationStyle.minimal,
      closeButtonShowType: CloseButtonShowType.always,
      // acknowledgmentRequired ? null : const Duration(seconds: 6),
      description: Text(
        text,
        maxLines: 6,
        style: const TextStyle(color: Colors.black, fontSize: 18),
      ),
      icon: const Icon(Icons.error_outline),
      alignment: Alignment.center,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black, // Sets the close button color to black
    );
  }
}
