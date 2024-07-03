// ignore_for_file: avoid_classes_with_only_static_members

import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import 'hmb_text_scroll.dart';

class HMBToast {
  static void info(String text) {
    toastification.show(
        type: ToastificationType.info,
        style: ToastificationStyle.minimal,
        autoCloseDuration: const Duration(seconds: 3),
        // toast: Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        //   decoration: BoxDecoration(
        //     borderRadius: BorderRadius.circular(25),
        //     color: Colors.black87, // Set your desired background color here
        //   ),
        //   child: Text(
        //     text,
        //     style: const TextStyle(
        //         color: Colors.white), // Set text color for better contrast
        //   ),
        // ),
        description: Text(text));
  }

  static void error(String text, {bool acknowledgmentRequired = false}) {
    late final ToastificationItem notification;
    notification = toastification.show(
        type: ToastificationType.error,
        closeButtonShowType: acknowledgmentRequired
            ? CloseButtonShowType.always
            : CloseButtonShowType.onHover,
        autoCloseDuration:
            acknowledgmentRequired ? null : const Duration(seconds: 6),
        // toast: Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        //   decoration: BoxDecoration(
        //     borderRadius: BorderRadius.circular(25),
        //     color: Colors.orange, // Set your desired background color here
        //   ),
        description: _buildMessage(text,
            acknowledgmentRequired: acknowledgmentRequired,
            onPressed: () => toastification.dismiss(notification)),
        alignment: Alignment.center,
        style: ToastificationStyle.minimal,
        backgroundColor: Colors.orangeAccent);
  }

  static Widget _buildMessage(String text,
      {required void Function() onPressed,
      bool acknowledgmentRequired = false}) {
    if (acknowledgmentRequired) {
      return Row(children: [
        // HMBButton(label: 'Ack', onPressed: () => onPressed),
        if (text.length > 80)
          HMBScrollText(
            text: text,
          )
        else
          Text(
            text,
            style: const TextStyle(
                color: Colors.white), // Set text color for better contrast
          )
      ]);
    } else {
      return Text(
        text,
        style: const TextStyle(
            color: Colors.white), // Set text color for better contrast
      );
    }
  }
}
