import 'package:flutter/material.dart';

import '../widgets/hmb_date_time_picker.dart'; // HMBDateTimeField + enums
import '../widgets/layout/hmb_spacer.dart';
import '../widgets/text/hmb_text.dart';

class HMBSnoozePicker {
  /// Opens a dialog with HMBDateTimeField and returns a Duration to snooze by.
  /// The duration is computed relative to [base] (usually t.dueDate or now).
  static Future<Duration?> pickSnoozeDuration(
    BuildContext context, {
    required DateTime base,
    DateTime? initial, // prefilled value; defaults to base + 1h
    HMBDateTimeFieldMode mode = HMBDateTimeFieldMode.dateAndTime,
  }) async {
    final now = DateTime.now();
    var selected = initial ?? base.add(const Duration(hours: 1));

    String? validator(DateTime? v) {
      if (v == null) {
        return 'Please choose a date/time';
      }
      if (!v.isAfter(now)) {
        return 'Pick a future time';
      }
      return null;
    }

    return showDialog<Duration?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const HMBText('Choose date & time', bold: true),
        content: SizedBox(
          width: 420,
          child: HMBDateTimeField(
            label: 'Reminder',
            initialDateTime: selected,
            mode: mode,
            validator: validator,
            onChanged: (dt) => selected = dt,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          const HMBSpacer(width: true),
          FilledButton(
            onPressed: () {
              final err = validator(selected);
              if (err != null) {
                return;
              }
              final by = selected.difference(base);
              Navigator.of(ctx).pop(by);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
