// ignore_for_file: avoid_classes_with_only_static_members

import 'package:flutter/material.dart';
import 'package:ftoast/ftoast.dart';

class HMBToast {
  static void notice(BuildContext context, String text) {
    FToast.toast(
      context,
      toast: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Colors.black87, // Set your desired background color here
        ),
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white), // Set text color for better contrast
        ),
      ),
    );
  }

  static void error(BuildContext context, String text) {
    FToast.toast(
      context,
      duration: 6000,
      toast: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Colors.orange, // Set your desired background color here
        ),
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white), // Set text color for better contrast
        ),
      ),
    );
  }
}
